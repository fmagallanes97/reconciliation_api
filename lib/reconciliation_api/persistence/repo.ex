defmodule ReconciliationApi.Repo do
  use Ecto.Repo,
    otp_app: :reconciliation_api,
    adapter: Ecto.Adapters.Postgres
end
