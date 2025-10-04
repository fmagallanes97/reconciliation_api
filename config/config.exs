import Config

config :reconciliation_api, ReconciliationApi.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  database: System.get_env("DB_NAME", "reconciliation_api_db"),
  hostname: System.get_env("DB_HOST", "db"),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))

config :reconciliation_api, ecto_repos: [ReconciliationApi.Repo]

config :reconciliation_api, :mock,
  days_back: 10,
  advance_interval_ms: 60_000,
  transactions_added_per_minute: 100,
  duplicate_probability: 0.5

config :reconciliation_api, :sync,
  page_size: 100,
  pages_to_check: 11,
  concurrent_workers: 4

config :reconciliation_api, :env, Mix.env()
