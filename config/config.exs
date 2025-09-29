import Config

config :reconciliation_api, TransactionApi.Repo,
  username: "postgres",
  password: "postgres",
  database: "reconciliation_api_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
