# frozen_string_literal: true

lib = ::File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lazy_data/version"

::Gem::Specification.new do |spec|
  spec.name = "lazy_data"
  spec.version = ::LazyData::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "Comprehensive implementation of lazily computed data"
  spec.description =
    "LazyData provides data types featuring thread-safe lazy computation. " \
    "These objects are constructed with a block that can be called to " \
    "compute the final value, but it is not actually called until the value" \
    "is requested. Once requested, the computation takes place only once, " \
    "in the first thread that requested the value. Future requests will " \
    "return a cached value. Furthermore, any other threads that request " \
    "the value during the initial computation will block until the first " \
    "thread has completed the computation. This implementation also " \
    "provides retry and expiration features. The code was extracted from " \
    "the google-cloud-env gem that originally used it."
  spec.license = "Apache-2.0"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               (::Dir.glob("*.md") - ["CLAUDE.md", "AGENTS.md"]) +
               ::Dir.glob("docs/*.md") + [".yardopts"]
  spec.required_ruby_version = ">= 2.7.0"
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    spec.metadata["changelog_uri"] = "https://dazuma.github.io/lazy_data/v#{::LazyData::VERSION}/file.CHANGELOG.html"
    spec.metadata["source_code_uri"] = "https://github.com/dazuma/lazy_data/tree/lazy_data/v#{::LazyData::VERSION}"
    spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/lazy_data/issues"
    spec.metadata["documentation_uri"] = "https://dazuma.github.io/lazy_data/v#{::LazyData::VERSION}"
  end
end
