defmodule ReconciliationApi.Sync.Job do
  @moduledoc """
  Background job that runs two syncs:
  - Incremental sync: runs every minute, syncing recent pages.
  - Deep scan (full sync): runs every hour, syncing all pages.
  """

  use GenServer

  @interval_ms 60_000
  @full_sync_interval_ms 3_600_000

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
    # Incremental sync: recent pages only
    ReconciliationApi.Sync.concurrent_sync(
      page_size(),
      pages_to_check(),
      concurrent_workers(),
      :incremental
    )

    schedule_sync()
    {:noreply, state}
  end

  def handle_info(:run_full_sync, state) do
    # Deep scan: sync all pages
    response = TransactionApi.Mock.ExternalApi.ExternalApiMock.fetch_transactions(1, page_size())
    total_pages = response["total_pages"]
    ReconciliationApi.Sync.concurrent_sync(page_size(), total_pages, concurrent_workers(), :full)
    schedule_full_sync()
    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :run_sync, @interval_ms)
  end

  defp schedule_full_sync do
    Process.send_after(self(), :run_full_sync, @full_sync_interval_ms)
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
end
