defmodule ReconciliationApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Mix.env() == :test do
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
end
