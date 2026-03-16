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

require "lazy_data/dict"
require "lazy_data/expiry"
require "lazy_data/retries"
require "lazy_data/value"
require "lazy_data/version"

##
# LazyData provides data types featuring thread-safe lazy computation.
#
# LazyData objects are constructed with a block that can be called to compute
# the final value, but it is not actually called until the value is requested.
# Once requested, the computation takes place only once, in the first thread
# that requested the value. Future requests will return a cached value.
# Furthermore, any other threads that request the value during the initial
# computation will block until the first thread has completed the computation.
#
# This implementation also provides retry and expiration features. The code was
# extracted from the google-cloud-env gem that originally used it.
#
module LazyData
end
