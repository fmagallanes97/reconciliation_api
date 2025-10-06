import Config

config :reconciliation_api, :env, Mix.env()

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL", "debug"))

config :reconciliation_api, ReconciliationApi.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  database: System.get_env("DB_NAME", "reconciliation_api_db"),
  hostname: System.get_env("DB_HOST", "db"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  log: false

config :reconciliation_api, ecto_repos: [ReconciliationApi.Repo]

config :reconciliation_api, :mock,
  days_back: 1,
  advance_interval_ms: 60_000,
  transactions_added_per_minute: 10,
  duplicate_probability: 0.5,
  error_probability: 0.01

config :reconciliation_api, :sync,
  page_size: 100,
  pages_to_check: 11,
  concurrent_workers: 4,
  incremental_sync_interval_ms: 60_000,
  full_sync_interval_ms: 3_600_000

config :mnesia,
  dir: String.to_charlist(System.get_env("MNESIA_DIR", "/mnesia"))
