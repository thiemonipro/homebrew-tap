# Thiemonipro Tap

## OpenCode Cost Tracker

```sh
brew install thiemonipro/tap/opencode-cost-tracker
opencode-cost-tracker
```

Open http://localhost:4174 to view estimated LLM costs from your local OpenCode session history.
Node.js 24 is installed automatically. Install OpenCode separately, or set `OPENCODE_DB_PATH` to an existing OpenCode SQLite database.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "thiemonipro/tap"
brew "opencode-cost-tracker"
```

## Documentation

See the [application README](https://github.com/thiemonipro/opencode_cost_tracker) for configuration and features.

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
