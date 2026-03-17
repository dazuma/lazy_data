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
require "lazy_data/internal_state"
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
# * {LazyData::Value} holds a single value
# * {LazyData::Dict} holds a dictionary of values, where each key points to a
#   separate lazy value
#
# This implementation also provides retry and expiration features. The code was
# extracted from the google-cloud-env gem that originally used it.
#
module LazyData
  class << self
    ##
    # Create a LazyData::Value.
    #
    # You must pass a block that will be called to compute the value the first
    # time it is accessed. The block should evaluate to the desired value, or
    # raise an exception on error. To specify a value that expires, use
    # {LazyData.expiring_value}. To raise an exception that expires, use
    # {LazyData.raise_expiring_error}.
    #
    # You can optionally pass a retry manager, which controls how subsequent
    # accesses might try calling the block again if a compute attempt fails
    # with an exception. A retry manager should either be an instance of
    # {LazyData::Retries} or an object that duck types it.
    #
    # @param retries [LazyData::Retries] A retry manager. The default is a
    #     retry manager that tries only once.
    # @param lifetime [Numeric,nil] The default lifetime of a computed value.
    #     Optional. No expiration by default if not provided. This can be
    #     overridden in the block by returning {LazyData.expiring_value} or
    #     calling {LazyData.raise_expiring_error} explicitly.
    # @param block [Proc] A block that can be called to attempt to compute
    #     the value.
    #
    def value(retries: nil, lifetime: nil, &block)
      LazyData::Value.new(retries: retries, lifetime: lifetime, &block)
    end

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
    # @param lifetime [Numeric,nil] The default lifetime of a computed value.
    #     Optional. No expiration by default if not provided. This can be
    #     overridden in the block by returning {LazyData.expiring_value} or
    #     calling {LazyData.raise_expiring_error} explicitly.
    # @param block [Proc] A block that can be called to attempt to compute the
    #     value given the key.
    #
    def dict(retries: nil, lifetime: nil, &block)
      LazyData::Dict.new(retries: retries, lifetime: lifetime, &block)
    end
  end
end
