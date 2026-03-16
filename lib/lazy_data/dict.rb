# frozen_string_literal: true

# Portions copyright 2023 Google LLC
#
# This code has been modified from the original Google code. The modified
# portions copyright 2026 Daniel Azuma
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module LazyData
  ##
  # This expands on {LazyData::Value} by providing a lazy key-value dictionary.
  # Each key uses a separate {LazyData::Value}; hence multiple keys can be in
  # the process of computation concurrently and independently.
  #
  class Dict
    ##
    # Create a LazyData::Dict.
    #
    # You must pass a block that will be called to compute the value the first
    # time it is accessed. The block takes the key as an argument and should
    # evaluate to the value for that key, or raise an exception on error. To
    # specify a value that expires, use {LazyData.expiring_value}. To raise an
    # exception that expires, use {LazyData.raise_expiring_error}.
    #
    # You can optionally pass a retry manager, which controls how subsequent
    # accesses might try calling the block again if a compute attempt fails
    # with an exception. A retry manager should either be an instance of
    # {LazyData::Retries} or an object that duck types it.
    #
    # @param retries [Retries,Proc] A retry manager. The default is a retry
    #     manager that tries only once. You can provide either a static retry
    #     manager or a Proc that returns a retry manager.
    # @param block [Proc] A block that can be called to attempt to compute the
    #     value given the key.
    #
    def initialize(retries: nil, &block)
      @retries = retries
      @compute_handler = block
      @key_values = {}
      @mutex = ::Thread::Mutex.new
    end

    ##
    # Returns the value for the given key. This will either return the value or
    # raise an error indicating failure to compute the value. If the value was
    # previously cached, it will return that cached value, otherwise it will
    # either run the computation to try to determine the value, or wait for
    # another thread that is already running the computation.
    #
    # Any arguments beyond the initial key argument will be passed to the block
    # if it is called, but are ignored if a cached value is returned.
    #
    # @param key [Object] the key
    # @param extra_args [Array] extra arguments to pass to the block
    # @return [Object] the value
    # @raise [Exception] if an error happened while computing the value
    #
    def get(key, *extra_args)
      lookup_key(key).get(key, *extra_args)
    end
    alias [] get

    ##
    # This method calls {#get} repeatedly until a final result is available or
    # retries have exhausted.
    #
    # Note: this method spins on {#get}, although honoring any retry delay.
    # Thus, it is best to call this only if retries are limited or a retry
    # delay has been configured.
    #
    # @param key [Object] the key
    # @param extra_args [Array] extra arguments to pass to the block
    # @param transient_errors [Array<Class>] An array of exception classes that
    #     will be treated as transient and will allow await to continue
    #     retrying. Exceptions omitted from this list will be treated as fatal
    #     errors and abort the call. Default is `[StandardError]`.
    # @param max_tries [Integer,nil] The maximum number of times this will call
    #     {#get} before giving up, or nil for a potentially unlimited number of
    #     attempts. Default is 1.
    # @param max_time [Numeric,nil] The maximum time in seconds this will spend
    #     before giving up, or nil (the default) for a potentially unlimited
    #     timeout.
    #
    # @return [Object] the value
    # @raise [Exception] if a fatal error happened, or retries have been
    #     exhausted.
    #
    def await(key, extra_args, transient_errors: nil, max_tries: 1, max_time: nil)
      lookup_key(key).await(key, *extra_args,
                            transient_errors: transient_errors,
                            max_tries: max_tries,
                            max_time: max_time)
    end

    ##
    # Returns the current low-level state for the given key. Does not block for
    # computation. See {LazyData::Value#internal_state} for details.
    #
    # @param key [Object] the key
    # @return [Array] the low-level state
    #
    def internal_state(key)
      lookup_key(key).internal_state
    end

    ##
    # Force the cache for the given key to expire immediately, if computation
    # is complete.
    #
    # Any cached value will be cleared, the retry count is reset, and the next
    # access will call the compute block as if it were the first access.
    # Returns true if this took place. Has no effect and returns false if the
    # computation is not yet complete (i.e. if a thread is currently computing,
    # or if the last attempt failed and retries have not yet been exhausted.)
    #
    # @param key [Object] the key
    # @return [true,false] whether the cache was expired
    #
    def expire!(key)
      lookup_key(key).expire!
    end

    ##
    # Force the values for all keys to expire immediately.
    #
    # @return [Array<Object>] A list of keys that were expired. A key is *not*
    #     included if its computation is not yet complete (i.e. if a thread is
    #     currently computing, or if the last attempt failed and retries have
    #     not yet been exhausted.)
    #
    def expire_all!
      all_expired = []
      @mutex.synchronize do
        @key_values.each do |key, value|
          all_expired << key if value.expire!
        end
      end
      all_expired
    end

    ##
    # Set the cache value for the given key explicitly and immediately. If a
    # computation is in progress, it is "detached" and its result will no
    # longer be considered.
    #
    # @param key [Object] the key
    # @param value [Object] the value to set
    # @param lifetime [Numeric] the lifetime until expiration in seconds, or
    #     nil (the default) for no expiration.
    # @return [Object] the value
    #
    def set!(key, value, lifetime: nil)
      lookup_key(key).set!(value, lifetime: lifetime)
    end

    private

    ##
    # Ensures that exactly one LazyData::Value exists for the given key, and
    # returns it.
    #
    def lookup_key(key)
      # Optimization: check for key existence and return quickly without
      # grabbing the mutex. This works because keys are never deleted.
      return @key_values[key] if @key_values.key? key

      @mutex.synchronize do
        if @key_values.key?(key)
          @key_values[key]
        else
          retries =
            if @retries.respond_to?(:reset_dup)
              @retries.reset_dup
            elsif @retries.respond_to?(:call)
              @retries.call
            end
          @key_values[key] = Value.new(retries: retries, &@compute_handler)
        end
      end
    end
  end
end
