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

# Main documentation is in lib/lazy_data.rb
module LazyData
  class << self
    ##
    # Creates a special object that can be returned from a computation to
    # indicate that a value expires after the given number of seconds. Any
    # access after the expiration will cause a recomputation.
    #
    # @param lifetime [Numeric,nil] timeout in seconds, or nil to explicitly
    #     disable expiration
    # @param value [Object] the computation result
    #
    def expiring_value(lifetime, value)
      return value unless lifetime
      ExpiringValue.new(lifetime, value)
    end

    ##
    # Raise an error that, if it is the final result (i.e. retries have been
    # exhausted), will expire after the given number of seconds. Any access
    # after the expiration will cause a recomputation. If retries will not have
    # been exhausted, expiration is ignored.
    #
    # The error can be specified as an exception object, a string (in which
    # case a RuntimeError will be raised), or a class that descends from
    # Exception (in which case an error of that type will be created, and
    # passed any additional args given).
    #
    # @param lifetime [Numeric,nil] timeout in seconds, or nil to explicitly
    #     disable expiration
    # @param error [String,Exception,Class] the error to raise
    # @param args [Array] any arguments to pass to an error constructor
    #
    def raise_expiring_error(lifetime, error, *args)
      raise error unless lifetime
      raise ExpiringError, lifetime if error.equal?($!)
      if error.is_a?(::Class) && error.ancestors.include?(::Exception)
        error = error.new(*args)
      elsif !error.is_a?(::Exception)
        error = ::RuntimeError.new(error.to_s)
      end
      begin
        raise error
      rescue error.class
        raise ExpiringError, lifetime
      end
    end
  end

  ##
  # @private
  # Internal type signaling a value with an expiration
  #
  class ExpiringValue
    def initialize(lifetime, value)
      @lifetime = lifetime
      @value = value
    end

    attr_reader :lifetime
    attr_reader :value
  end

  ##
  # @private
  # Internal type signaling an error with an expiration.
  #
  class ExpiringError < StandardError
    def initialize(lifetime)
      super()
      @lifetime = lifetime
    end

    attr_reader :lifetime
  end
end
