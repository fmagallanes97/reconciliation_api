defmodule ReconciliationApi.Sync.Supervisor do
  @moduledoc """
  Supervisor for concurrent sync tasks in ReconciliationApi.Sync.
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Task.Supervisor, name: ReconciliationApi.SyncSupervisor},
      ReconciliationApi.Sync.Job
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
