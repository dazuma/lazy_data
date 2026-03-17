# frozen_string_literal: true

# Copyright 2026 Daniel Azuma
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
  # A representation of the internal state of a {LazyData::Value}.
  #
  class InternalState
    ##
    # The FAILED state indicates that computation has failed finally and no
    # more retries will be done. If the state is FAILED, and error will be
    # present and the value will be nil. The expires_at time will be a
    # CLOCK_MONOTONIC timestamp if the failure can expire, or nil if not.
    #
    FAILED = :failed

    ##
    # The SUCCESS state indicates that computation has completed successfully,
    # and the value is set. The error will be nil. The expires_at time will be
    # a CLOCK_MONOTONIC timestamp if the value can expire, or nil if not.
    #
    SUCCESS = :success

    ##
    # The PENDING state indicates the value has not been computed, or that
    # previous computation attempts have failed but there are retries pending.
    # The error will be set to the most recent error, or nil if no computation
    # attempt has yet been started. The value will be nil. The expires_at time
    # will be the CLOCK_MONOTONIC timestamp when the current retry delay will
    # end (or has ended, so it could be in the past), or nil if there are no
    # retry delays.
    #
    PENDING = :pending

    ##
    # The COMPUTING state indicates that a thread is currently computing the
    # value. The error and value will both be nil. The expires_at time will be
    # the CLOCK_MONOTONIC timestamp when the computation had started.
    #
    COMPUTING = :computing

    ##
    # The general state of the value. Will be {PENDING}, {COMPUTING},
    # {SUCCESS}, or {FAILED}.
    #
    # @return [Symbol]
    #
    attr_reader :state

    ##
    # The current computed value, if the state is {SUCCESS}, or nil for any
    # other state
    #
    # @return [Object]
    #
    attr_reader :value

    ##
    # The last computation error, if the state is {FAILED} or {PENDING},
    # otherwise nil.
    #
    # @return [Exception,nil]
    #
    attr_reader :error

    ##
    # The CLOCK_MONOTONIC timestamp of expiration, or the start of the current
    # computation when in {COMPUTING} state.
    #
    # @return [Numeric,nil]
    #
    attr_reader :expires_at

    ##
    # Query whether the state is failure
    #
    # @return [boolean]
    #
    def failed?
      state == FAILED
    end

    ##
    # Query whether the state is success
    #
    # @return [boolean]
    #
    def success?
      state == SUCCESS
    end

    ##
    # Query whether the state is pending
    #
    # @return [boolean]
    #
    def pending?
      state == PENDING
    end

    ##
    # Query whether the state is computing
    #
    # @return [boolean]
    #
    def computing?
      state == COMPUTING
    end

    ##
    # @private
    #
    def initialize(state, value, error, expires_at)
      @state = state
      @value = value
      @error = error
      @expires_at = expires_at
      freeze
    end
  end
end
