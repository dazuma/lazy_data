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

require "helper"

describe LazyData::Retries do
  describe "initialization" do
    it "starts in a non-finished state" do
      retries = LazyData::Retries.new
      assert_equal false, retries.finished?
    end

    it "raises on zero max_tries" do
      assert_raises ArgumentError do
        LazyData::Retries.new(max_tries: 0)
      end
    end

    it "raises on negative max_tries" do
      assert_raises ArgumentError do
        LazyData::Retries.new(max_tries: -1)
      end
    end

    it "raises on zero max_time" do
      assert_raises ArgumentError do
        LazyData::Retries.new(max_time: 0)
      end
    end

    it "raises on negative max_time" do
      assert_raises ArgumentError do
        LazyData::Retries.new(max_time: -1)
      end
    end

    it "raises on negative initial_delay" do
      assert_raises ArgumentError do
        LazyData::Retries.new(initial_delay: -1)
      end
    end

    it "raises on negative max_delay" do
      assert_raises ArgumentError do
        LazyData::Retries.new(max_delay: -1)
      end
    end

    it "allows nil max_tries for unlimited retries" do
      retries = LazyData::Retries.new(max_tries: nil)
      assert_equal false, retries.finished?
    end
  end

  describe "#finish!" do
    it "transitions to finished state" do
      retries = LazyData::Retries.new
      retries.finish!
      assert_equal true, retries.finished?
    end

    it "returns self" do
      retries = LazyData::Retries.new
      assert_same retries, retries.finish!
    end
  end

  describe "#reset!" do
    it "transitions from finished back to non-finished" do
      retries = LazyData::Retries.new
      retries.finish!
      assert_equal true, retries.finished?
      retries.reset!
      assert_equal false, retries.finished?
    end

    it "returns self" do
      retries = LazyData::Retries.new
      assert_same retries, retries.reset!
    end
  end

  describe "#next" do
    it "raises if already finished" do
      retries = LazyData::Retries.new
      retries.finish!
      err = assert_raises RuntimeError do
        retries.next
      end
      assert_equal "no tries remaining", err.message
    end

    it "returns nil on first call with max_tries 1" do
      retries = LazyData::Retries.new(max_tries: 1)
      assert_nil retries.next
    end

    it "finishes after returning nil" do
      retries = LazyData::Retries.new(max_tries: 1)
      retries.next
      assert_equal true, retries.finished?
    end

    it "returns the initial delay on first call" do
      retries = LazyData::Retries.new(max_tries: 3, initial_delay: 0.5)
      assert_equal 0.5, retries.next
    end

    it "counts down tries correctly" do
      retries = LazyData::Retries.new(max_tries: 3)
      assert_equal 0, retries.next    # first attempt, 2 remaining
      assert_equal 0, retries.next    # second attempt, 1 remaining
      assert_nil retries.next         # third attempt, 0 remaining -> finished
      assert_equal true, retries.finished?
    end

    it "applies delay_multiplier for exponential backoff" do
      retries = LazyData::Retries.new(max_tries: 4, initial_delay: 1, delay_multiplier: 2)
      assert_equal 1, retries.next    # initial_delay
      assert_equal 2, retries.next    # 1 * 2
      assert_equal 4, retries.next    # 2 * 2
      assert_nil retries.next         # finished
    end

    it "applies delay_adder for linear backoff" do
      retries = LazyData::Retries.new(max_tries: 4, initial_delay: 1, delay_adder: 0.5)
      assert_equal 1, retries.next    # initial_delay
      assert_equal 1.5, retries.next  # 1 + 0.5
      assert_equal 2.0, retries.next  # 1.5 + 0.5
      assert_nil retries.next         # finished
    end

    it "applies both delay_multiplier and delay_adder" do
      retries = LazyData::Retries.new(max_tries: 4, initial_delay: 1, delay_multiplier: 2, delay_adder: 0.1)
      assert_equal 1, retries.next      # initial_delay
      assert_equal 2.1, retries.next    # (1 * 2) + 0.1
      assert_equal 4.3, retries.next    # (2.1 * 2) + 0.1
      assert_nil retries.next           # finished
    end

    it "caps delay at max_delay" do
      retries = LazyData::Retries.new(max_tries: 5, initial_delay: 1, delay_multiplier: 10, max_delay: 5)
      assert_equal 1, retries.next    # initial_delay
      assert_equal 5, retries.next    # 10 capped to 5
      assert_equal 5, retries.next    # 50 capped to 5
      assert_equal 5, retries.next    # still capped
      assert_nil retries.next         # finished
    end

    it "retries indefinitely with nil max_tries" do
      retries = LazyData::Retries.new(max_tries: nil)
      100.times do
        assert_equal 0, retries.next
      end
      assert_equal false, retries.finished?
    end

    it "stops when max_time is exceeded" do
      retries = LazyData::Retries.new(max_tries: nil, max_time: 0.1, initial_delay: 0.2)
      # The delay (0.2) exceeds max_time (0.1), so this should finish
      assert_nil retries.next
      assert_equal true, retries.finished?
    end

    it "allows retries within max_time" do
      retries = LazyData::Retries.new(max_tries: nil, max_time: 10, initial_delay: 0.01)
      delay = retries.next
      assert_equal 0.01, delay
      assert_equal false, retries.finished?
    end

    it "deducts elapsed time from delay when delay_includes_time_elapsed is set" do
      retries = LazyData::Retries.new(max_tries: 2, initial_delay: 1, delay_includes_time_elapsed: true)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 0.3
      delay = retries.next(start_time: start_time)
      assert_in_delta 0.7, delay, 0.05
    end

    it "clamps elapsed-adjusted delay to zero" do
      retries = LazyData::Retries.new(max_tries: 2, initial_delay: 0.1, delay_includes_time_elapsed: true)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 10
      delay = retries.next(start_time: start_time)
      assert_equal 0, delay
    end

    it "ignores start_time when delay_includes_time_elapsed is false" do
      retries = LazyData::Retries.new(max_tries: 2, initial_delay: 1)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 0.5
      delay = retries.next(start_time: start_time)
      assert_equal 1, delay
    end

    it "ignores delay_includes_time_elapsed when start_time is nil" do
      retries = LazyData::Retries.new(max_tries: 2, initial_delay: 1, delay_includes_time_elapsed: true)
      delay = retries.next
      assert_equal 1, delay
    end

    it "returns zero delay with default initial_delay" do
      retries = LazyData::Retries.new(max_tries: 2)
      assert_equal 0, retries.next
    end
  end

  describe "#reset_dup" do
    it "returns a new instance in reset state" do
      retries = LazyData::Retries.new(max_tries: 3, initial_delay: 0.5)
      retries.next
      dup = retries.reset_dup
      refute_same retries, dup
      assert_equal false, dup.finished?
    end

    it "preserves configuration" do
      retries = LazyData::Retries.new(max_tries: 3, initial_delay: 0.5, delay_multiplier: 2)
      dup = retries.reset_dup
      # The dup should behave identically to a fresh instance with the same config
      assert_equal 0.5, dup.next
      assert_equal 1.0, dup.next
      assert_nil dup.next
    end

    it "does not share state with the original" do
      retries = LazyData::Retries.new(max_tries: 3)
      retries.next  # consume one try
      dup = retries.reset_dup
      # Original has 2 tries left, dup should have all 3
      assert_equal 0, dup.next
      assert_equal 0, dup.next
      assert_nil dup.next
    end
  end

  describe "reset and reuse" do
    it "can be reset after finishing and reused" do
      retries = LazyData::Retries.new(max_tries: 2, initial_delay: 0.5)
      assert_equal 0.5, retries.next
      assert_nil retries.next
      assert_equal true, retries.finished?

      retries.reset!
      assert_equal false, retries.finished?
      assert_equal 0.5, retries.next
      assert_nil retries.next
      assert_equal true, retries.finished?
    end

    it "can be reset mid-sequence" do
      retries = LazyData::Retries.new(max_tries: 3, initial_delay: 1, delay_multiplier: 2)
      assert_equal 1, retries.next
      # Reset before exhausting tries
      retries.reset!
      # Should start fresh with the initial delay again
      assert_equal 1, retries.next
      assert_equal 2, retries.next
      assert_nil retries.next
    end
  end
end
