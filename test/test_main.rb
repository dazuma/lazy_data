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

describe LazyData do
  it "creates a value" do
    val = LazyData.value do
      1
    end
    assert_kind_of(LazyData::Value, val)
    assert_equal(1, val.get)
  end

  it "creates a dict" do
    count = 0
    dict = LazyData.dict do |num|
      count += 1
      "#{num}-#{count}"
    end
    assert_kind_of(LazyData::Dict, dict)
    assert_equal "1-1", dict.get(1)
    assert_equal "12-2", dict.get(12)
  end
end
