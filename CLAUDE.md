# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

This project uses [Toys](https://dazuma.github.io/toys) (not Rake) for build automation.

```bash
toys ci          # Run full CI pipeline

toys test        # Run unit tests only
toys rubocop     # Run linting only
toys yardoc      # Generate documentation
toys build       # Build gem package

toys test test/test_value.rb  # Run a single test file
```

Use `minitest-focus` to run a specific test by adding `focus` before `it` blocks.

## Architecture

LazyData is a Ruby gem providing thread-safe lazy computation primitives. Values are computed on-demand, memoized, and shared across threads. There are no external gem runtime dependencies.

### Core Classes

**`LazyData::Value`** (`lib/lazy_data/value.rb`) — The primary class. Wraps a block whose result is computed once on first access and cached. Implements a 3-state machine (Pending → Computing → Finished) protected by a mutex and condition variables. Only one thread runs the computation; others wait and receive the same result. Supports:
- Exception caching (failed computations are also memoized)
- Configurable retry with exponential backoff via `LazyData::Retries`
- Value/error expiration using monotonic time
- Manual override via `set!` and `expire!`

**`LazyData::Dict`** (`lib/lazy_data/dict.rb`) — A key-value container where each key maps to an independent `LazyData::Value`. Different keys can compute concurrently.

**`LazyData::Retries`** (`lib/lazy_data/retries.rb`) — Manages retry scheduling with configurable `max_tries`, `max_time`, initial `delay`, and exponential `multiplier`.

**`LazyData::Expiry`** (`lib/lazy_data/expiry.rb`) — Provides `LazyData.expiring_value(lifetime, value)` and `LazyData.raise_expiring_error(lifetime, error)` helpers. When a computation block returns an `ExpiringValue` or raises an `ExpiringError`, the cached result automatically expires after the given lifetime, triggering recomputation on the next access.

### Threading Model

`LazyData::Value` uses a mutex plus two condition variables (`compute_notify` for the computing thread, `backfill_notify` for waiting threads). The "backfill" pattern ensures waiting threads complete in phases to avoid races when expiration is involved. Deadlock prevention guards against re-entrant access from the same thread during computation.

### Testing

Tests use Minitest with `describe`/`it` syntax with assertions. `test/helper.rb` sets up the test environment.

## General coding instructions

- Unless instructed otherwise, always use red-green test-driven development when making code changes. For each step in a coding task, first write tests and confirm they fail. Then write code to make the tests pass.
- Unless instructed otherwise, always git commit after a step is complete and the tests pass.
- Conventional Commits format required (`fix:`, `feat:`, `docs:`, etc.)
- Prefer Ruby for any one-off scripts you need to write as part of your work.
