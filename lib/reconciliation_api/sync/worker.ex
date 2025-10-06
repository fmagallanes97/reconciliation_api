defmodule ReconciliationApi.Sync.Worker do
  @moduledoc """
  A GenServer-based background worker that periodically runs two types of sync jobs:

  - **Incremental sync:** Runs at a configurable interval (default: every minute), syncing a subset of recent pages.
  - **Full sync (deep scan):** Runs at a configurable interval (default: every hour), syncing all pages.

  Sync intervals, page size, number of pages to check, and concurrency are all configurable via the `:reconciliation_api, :sync` application environment.
  This worker starts automatically and schedules both sync jobs on initialization.
  """

  use GenServer

  alias ReconciliationApi.Sync

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    send(self(), :run_full_sync)
    schedule_sync()
    schedule_full_sync()
    {:ok, state}
  end

  @impl true
  def handle_info(:run_sync, state) do
    opts = [
      page_size: page_size(),
      pages: pages_to_check(),
      mode: :incremental,
      concurrency: concurrent_workers()
    ]

    Sync.concurrent_sync(opts)
    schedule_sync()

    {:noreply, state}
  end

  def handle_info(:run_full_sync, state) do
    opts = [
      page_size: page_size(),
      mode: :full,
      concurrency: concurrent_workers()
    ]

    Sync.concurrent_sync(opts)
    schedule_full_sync()

    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :run_sync, incremental_sync_interval())
  end

  defp schedule_full_sync do
    Process.send_after(self(), :run_full_sync, full_sync_interval())
  end

  defp page_size do
    Application.get_env(:reconciliation_api, :sync)
    |> Keyword.get(:page_size, 100)
  end

  defp pages_to_check do
    Application.get_env(:reconciliation_api, :sync)
    |> Keyword.get(:pages_to_check, 5)
  end

  defp concurrent_workers do
    Application.get_env(:reconciliation_api, :sync)
    |> Keyword.get(:concurrent_workers, 4)
  end

  defp incremental_sync_interval do
    Application.get_env(:reconciliation_api, :sync)
    |> Keyword.get(:incremental_sync_interval, 60_000)
  end

  defp full_sync_interval do
    Application.get_env(:reconciliation_api, :sync)
    |> Keyword.get(:full_sync_interval, 3_600_000)
  end
end
