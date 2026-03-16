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

require "helper"

describe LazyData::Dict do
  let :lazy_dict do
    count = 0
    LazyData::Dict.new do |num, suffix = ""|
      count += 1
      "#{num}-#{count}#{suffix}"
    end
  end

  describe "#get" do
    it "returns the correct value for keys" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
    end

    it "calls the block only the first time" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
      assert_equal "12-2", lazy_dict.get(12)
      assert_equal "1-1", lazy_dict.get(1)
    end

    it "passes extra arguments" do
      assert_equal "1-1foo", lazy_dict.get(1, "foo")
      assert_equal "12-2bar", lazy_dict.get(12, "bar")
      assert_equal "1-1foo", lazy_dict.get(1, "baz")
    end
  end

  describe "#expire!" do
    it "expires the correct key" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
      assert_equal true, lazy_dict.expire!(1)
      assert_equal "1-3", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
    end
  end

  describe "#expire_all!" do
    it "returns the keys expired" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal false, lazy_dict.expire!(12)
      assert_equal [1], lazy_dict.expire_all!
      assert_equal "1-2", lazy_dict.get(1)
    end
  end
end
