defmodule ReconciliationApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    env = app_env()

    children =
      if env == :test do
        []
      else
        [
          ReconciliationApi.Repo,
          TransactionApi.Mock.ExternalApi.ExternalApiMock,
          ReconciliationApi.Sync.Supervisor
        ]
      end

    opts = [strategy: :one_for_one, name: ReconciliationApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp app_env do
    Application.get_env(:reconciliation_api, :env, :dev)
  end
end
