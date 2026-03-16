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

describe LazyData, ".expiring_value" do
  it "wraps a value with a lifetime" do
    result = LazyData.expiring_value(10, "hello")
    assert_instance_of LazyData::ExpiringValue, result
    assert_equal 10, result.lifetime
    assert_equal "hello", result.value
  end

  it "returns the value directly when lifetime is nil" do
    result = LazyData.expiring_value(nil, "hello")
    assert_equal "hello", result
    refute_instance_of LazyData::ExpiringValue, result
  end

  it "wraps a nil value" do
    result = LazyData.expiring_value(5, nil)
    assert_instance_of LazyData::ExpiringValue, result
    assert_equal 5, result.lifetime
    assert_nil result.value
  end

  it "wraps a numeric value" do
    result = LazyData.expiring_value(1, 42)
    assert_instance_of LazyData::ExpiringValue, result
    assert_equal 42, result.value
  end

  it "accepts a zero lifetime" do
    result = LazyData.expiring_value(0, "immediate")
    assert_instance_of LazyData::ExpiringValue, result
    assert_equal 0, result.lifetime
  end

  it "accepts a fractional lifetime" do
    result = LazyData.expiring_value(0.5, "half-second")
    assert_instance_of LazyData::ExpiringValue, result
    assert_equal 0.5, result.lifetime
  end
end

describe LazyData, ".raise_expiring_error" do
  it "raises an ExpiringError wrapping a string message" do
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(10, "something broke")
    end
    assert_equal 10, err.lifetime
    assert_instance_of RuntimeError, err.cause
    assert_equal "something broke", err.cause.message
  end

  it "raises an ExpiringError wrapping an exception instance" do
    original = ArgumentError.new("bad arg")
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(5, original)
    end
    assert_equal 5, err.lifetime
    assert_instance_of ArgumentError, err.cause
    assert_equal "bad arg", err.cause.message
  end

  it "raises an ExpiringError wrapping an exception class" do
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(3, TypeError)
    end
    assert_equal 3, err.lifetime
    assert_instance_of TypeError, err.cause
  end

  it "passes extra args to an exception class constructor" do
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(3, ArgumentError, "custom message")
    end
    assert_equal 3, err.lifetime
    assert_instance_of ArgumentError, err.cause
    assert_equal "custom message", err.cause.message
  end

  it "raises the error directly when lifetime is nil with a string" do
    err = assert_raises RuntimeError do
      LazyData.raise_expiring_error(nil, "plain error")
    end
    assert_equal "plain error", err.message
    refute_instance_of LazyData::ExpiringError, err
  end

  it "raises the error directly when lifetime is nil with an exception instance" do
    original = ArgumentError.new("bad arg")
    err = assert_raises ArgumentError do
      LazyData.raise_expiring_error(nil, original)
    end
    assert_same original, err
  end

  it "raises the error directly when lifetime is nil with an exception class" do
    err = assert_raises TypeError do
      LazyData.raise_expiring_error(nil, TypeError)
    end
    assert_instance_of TypeError, err
    refute_instance_of LazyData::ExpiringError, err
  end

  it "converts non-exception non-string to RuntimeError via to_s" do
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(1, 12_345)
    end
    assert_instance_of RuntimeError, err.cause
    assert_equal "12345", err.cause.message
  end

  it "wraps the current exception ($!) when error is equal to $!" do
    err = assert_raises LazyData::ExpiringError do
      raise "original"
    rescue StandardError => e
      LazyData.raise_expiring_error(7, e)
    end
    assert_equal 7, err.lifetime
    assert_instance_of RuntimeError, err.cause
    assert_equal "original", err.cause.message
  end

  it "sets the cause chain correctly for a string error" do
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(1, "oops")
    end
    cause = err.cause
    assert_instance_of RuntimeError, cause
    assert_equal "oops", cause.message
  end

  it "accepts a zero lifetime" do
    err = assert_raises LazyData::ExpiringError do
      LazyData.raise_expiring_error(0, "immediate")
    end
    assert_equal 0, err.lifetime
  end
end

describe LazyData::ExpiringValue do
  it "stores lifetime and value" do
    ev = LazyData::ExpiringValue.new(10, "data")
    assert_equal 10, ev.lifetime
    assert_equal "data", ev.value
  end
end

describe LazyData::ExpiringError do
  it "stores lifetime" do
    err = LazyData::ExpiringError.new(5)
    assert_equal 5, err.lifetime
  end

  it "is a StandardError" do
    err = LazyData::ExpiringError.new(1)
    assert_kind_of StandardError, err
  end

  it "has an empty message" do
    err = LazyData::ExpiringError.new(1)
    assert_equal "LazyData::ExpiringError", err.message
  end
end
