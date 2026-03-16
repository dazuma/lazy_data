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
  # A simple retry manager with optional delay and backoff. It retries until
  # either a configured maximum number of attempts has been reached, or a
  # configurable total time has elapsed since the first failure.
  #
  # This class is not thread-safe by itself. Access should be protected by an
  # external mutex.
  #
  class Retries
    ##
    # Create and initialize a retry manager.
    #
    # @param max_tries [Integer,nil] Maximum number of attempts before we give
    #     up altogether, or nil for no maximum. Default is 1, indicating one
    #     attempt and no retries.
    # @param max_time [Numeric,nil] The maximum amount of time in seconds until
    #     we give up altogether, or nil for no maximum. Default is nil.
    # @param initial_delay [Numeric] Initial delay between attempts, in
    #     seconds. Default is 0.
    # @param max_delay [Numeric,nil] Maximum delay between attempts, in
    #     seconds, or nil for no max. Default is nil.
    # @param delay_multiplier [Numeric] Multipler applied to the delay between
    #     attempts. Default is 1 for no change.
    # @param delay_adder [Numeric] Value added to the delay between attempts.
    #     Default is 0 for no change.
    # @param delay_includes_time_elapsed [true,false] Whether to deduct any
    #     time already elapsed from the retry delay. Default is false.
    #
    def initialize(max_tries: 1,
                   max_time: nil,
                   initial_delay: 0,
                   max_delay: nil,
                   delay_multiplier: 1,
                   delay_adder: 0,
                   delay_includes_time_elapsed: false)
      @max_tries = max_tries&.to_i
      raise ::ArgumentError, "max_tries must be positive" if @max_tries && !@max_tries.positive?
      @max_time = max_time
      raise ::ArgumentError, "max_time must be positive" if @max_time && !@max_time.positive?
      @initial_delay = initial_delay
      raise ::ArgumentError, "initial_delay must be nonnegative" if @initial_delay&.negative?
      @max_delay = max_delay
      raise ::ArgumentError, "max_delay must be nonnegative" if @max_delay&.negative?
      @delay_multiplier = delay_multiplier
      @delay_adder = delay_adder
      @delay_includes_time_elapsed = delay_includes_time_elapsed
      reset!
    end

    ##
    # Create a duplicate in the reset state
    #
    # @return [Retries]
    #
    def reset_dup
      Retries.new(max_tries: @max_tries,
                  max_time: @max_time,
                  initial_delay: @initial_delay,
                  max_delay: @max_delay,
                  delay_multiplier: @delay_multiplier,
                  delay_adder: @delay_adder,
                  delay_includes_time_elapsed: @delay_includes_time_elapsed)
    end

    ##
    # Returns true if the retry limit has been reached.
    #
    # @return [true,false]
    #
    def finished?
      @current_delay.nil?
    end

    ##
    # Reset to the initial attempt.
    #
    # @return [self]
    #
    def reset!
      @current_delay = :reset
      self
    end

    ##
    # Cause the retry limit to be reached immediately.
    #
    # @return [self]
    #
    def finish!
      @current_delay = nil
      self
    end

    ##
    # Advance to the next attempt.
    #
    # Returns nil if the retry limit has been reached. Otherwise, returns the
    # delay in seconds until the next retry (0 for no delay). Raises an error
    # if the previous call already returned nil.
    #
    # @param start_time [Numeric,nil] Optional start time in monotonic time
    #     units. Used if delay_includes_time_elapsed is set.
    # @return [Numeric,nil]
    #
    def next(start_time: nil)
      raise "no tries remaining" if finished?
      cur_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      if @current_delay == :reset
        setup_first_retry(cur_time)
      else
        advance_delay
      end
      advance_retry(cur_time)
      adjusted_delay(start_time, cur_time)
    end

    private

    def setup_first_retry(cur_time)
      @tries_remaining = @max_tries
      @deadline = @max_time ? cur_time + @max_time : nil
      @current_delay = @initial_delay
    end

    def advance_delay
      @current_delay = (@delay_multiplier * @current_delay) + @delay_adder
      @current_delay = @max_delay if @max_delay && @current_delay > @max_delay
    end

    def advance_retry(cur_time)
      @tries_remaining -= 1 if @tries_remaining
      @current_delay = nil if @tries_remaining&.zero? || (@deadline && cur_time + @current_delay > @deadline)
    end

    def adjusted_delay(start_time, cur_time)
      delay = @current_delay
      if @delay_includes_time_elapsed && start_time && delay
        delay -= cur_time - start_time
        delay = 0 if delay.negative?
      end
      delay
    end
  end
end
