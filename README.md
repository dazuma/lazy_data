# LazyData

LazyData provides data types featuring thread-safe lazy computation. These
objects are constructed with a block that can be called to compute the final
value, but it is not actually called until the value is requested. Once
requested, the computation takes place only once, in the first thread that
requested the value. Future requests will return a cached value. Furthermore,
any other threads that request the value during the initial computation will
block until the first thread has completed the computation. This implementation
also provides retry and expiration features. The code was extracted from the
google-cloud-env gem that originally used it.

## Quick start

Install lazy_data as a gem, or include it in your bundle.

```sh
gem install lazy_data
```

You can use `LazyData::Value` to lazily load or compute a single value. For
example, to load a web page:

```ruby
require "lazy_data"

# Creating a lazy value does not compute the value yet
lazy_content = LazyData::Value.new do
  require "net/http"
  Net::HTTP.get(URI("https://example.com"))
end

# The block runs and computes the value the first time the value is requested
content = lazy_content.get

# The computed value is cached, and subsequent requests return it
content2 = lazy_content.get
```

Importantly, `LazyData::Value` is thread-safe, and if multiple threads request
the value concurrently, only one thread will run the computation, while the
others will block until it completes.

## Features

LazyData is similar to `Concurrent::Delay`, part of the
[concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) gem.
However, it includes a number of additional features that were driven by use
cases from [google-cloud-env](https://github.com/googleapis/ruby-cloud-env),
from which the library was extracted. Among those:

### Retries

LazyData can be configured to retry failed computations, with minimum delays
between retries.

```ruby
require "lazy_data"

# Configure 5 tries with exponential backoff
retry_config = LazyData::Retries.new(max_tries: 5,
                                     initial_delay: 1,
                                     delay_multiplier: 1.5,
                                     max_delay: 10)

# The computation itself is unchanged
lazy_content = LazyData::Value.new(retries: retry_config) do
  require "net/http"
  Net::HTTP.get(URI("https://example.com"))
end

# Make repeated attempts to get the content, respecting the backoff setting
content = lazy_content.await

# Or make single attempts and retry manually
content = begin
  lazy_content.get
rescue StandardError => e
  # If the first attempt failed, and we retry immediately, this second
  # attempt could just reraised the cached exception if it happened before
  # the configured delay
  lazy_content.get # Likely reraises
end
```

### Expiration

Computed values can expire after a configured period of time, so that the next
subsequent request triggers the computation again.

```ruby
require "lazy_data"

# Modify the computation to return results that expire after 1 minute, or
# raise an error that will expire after 1 minute.
lazy_content = LazyData::Value do
  require "net/http"
  content = Net::HTTP.get(URI("https://example.com"))
  LazyData.expiring_value(60, content)
rescue StandardError => e
  LazyData.raise_expiring_error(60, e)
end

# Perform the computation to get the data
content = lazy_content.get

# Rerunning immediately will return the cached value which has not expired
content2 = lazy_content.get

# If we wait for the value to expire, the computation will run again
sleep(61)
content3 = lazy_content.get
```

### Lower-level API

In case you need more low-level control, the API provides advanced methods that
can set the value immediately, expire the value immediately, or query the
internal state.

```ruby
require "lazy_data"

lazy_content = LazyData::Value.new do
  require "net/http"
  Net::HTTP.get(URI("https://example.com"))
end

# Bypass the normal computation and set the value immediately
lazy_content.set!("Hello, world!")

# Retrieving the value does not perform computation but returns the manually
# cached value
content = lazy_content.get

# Expire the current value immediately
lazy_content.expire!

# Now retrieving the value will call the compute block
content2 = lazy_content.get
```

## Contributing

Development is done in GitHub at https://github.com/dazuma/lazy_data.

*   To file issues: https://github.com/dazuma/lazy_data/issues.
*   For questions and discussion, please do not file an issue. Instead, use the
    discussions feature: https://github.com/dazuma/lazy_data/discussions.
*   Pull requests are welcome, but I recommend first filing an issue, and/or
    discussing substantial changes in GitHub discussions, before implementing.

The library uses [toys](https://dazuma.github.io/toys) for testing and CI. To
run the test suite, `gem install toys` and then run `toys ci`. You can also run
unit tests, rubocop, and build tests independently.

## Copyright and licensing notes

This code was originally written by Daniel Azuma while working at Google, and
was part of the [google-cloud-env](https://github.com/googleapis/ruby-cloud-env)
gem. Because of that, the library is Apache 2.0 licensed, and portions remain
copyright Google, LLC. Daniel subsequently extracted and forked this library by
itself, and has continued to develop the fork. The original remains vendored in
the google-cloud-env code base.

    Portions copyright 2023 Google LLC

    This code has been modified from the original Google code. The modified
    portions copyright 2026 Daniel Azuma

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
