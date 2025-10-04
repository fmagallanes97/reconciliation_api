defmodule ReconciliationApi.Sync do
  @moduledoc """
  Handles incremental and full synchronization of transactions from the external API.
  """

  alias TransactionApi.Mock.ExternalApi.ExternalApiMock
  alias ReconciliationApi.Persistence.Schema.Transaction
  alias ReconciliationApi.Repo
  alias ReconciliationApi.Reconciliation

  require Logger

  def concurrent_sync(
        page_size,
        pages_to_check \\ 3,
        concurrency \\ 4,
        mode \\ :incremental
      ) do
    response = ExternalApiMock.fetch_transactions(1, page_size)
    total_pages = response["total_pages"]

    last_sync_date = Reconciliation.get_last_sync_date()

    start_page =
      case mode do
        :full -> 1
        :incremental -> max(total_pages - pages_to_check + 1, 1)
      end

    Task.Supervisor.async_stream(
      ReconciliationApi.SyncSupervisor,
      start_page..total_pages,
      fn page -> process_sync_page_with_retry(page, page_size, last_sync_date, mode, 3, 0) end,
      max_concurrency: concurrency,
      timeout: :infinity
    )
    |> Enum.to_list()
  end

  defp process_sync_page(page, page_size, last_sync_date, mode) do
    case ExternalApiMock.fetch_transactions(page, page_size) do
      %{"data" => data} ->
        new_data =
          case mode do
            :incremental ->
              Enum.filter(data, fn tx ->
                Date.from_iso8601!(tx["created_at"]) > last_sync_date
              end)

            :full ->
              data
          end

        batch_attrs =
          Enum.map(new_data, fn tx ->
            %{
              account_number: tx["account_number"],
              amount: Decimal.new(tx["amount"]),
              currency: tx["currency"],
              created_at: Date.from_iso8601!(tx["created_at"]),
              status: tx["status"]
              # occurrence_count will be set by db trigger
            }
          end)

        if batch_attrs != [] do
          Repo.insert_all(Transaction, batch_attrs, on_conflict: :nothing)
          Logger.info("Inserted #{length(batch_attrs)} new records from page #{page}.")
        end

        {:ok, batch_attrs}

      {:error, :timeout} ->
        {:error, :timeout, page}

      {:error, :rate_limit} ->
        {:error, :rate_limit, page}

      {:error, _reason} ->
        {:error, :api_failure, page}
    end
  end

  defp process_sync_page_with_retry(page, page_size, last_sync_date, mode, max_attempts, attempts) do
    case process_sync_page(page, page_size, last_sync_date, mode) do
      {:ok, result} ->
        Logger.info("Successfully synced page #{page}: inserted #{length(result)} records.")
        result

      {:error, :timeout, page} when attempts < max_attempts ->
        delay = backoff_with_jitter(attempts)

        Logger.warning(
          "Timeout syncing page #{page} (attempt #{attempts + 1}/#{max_attempts}), retrying in #{delay}ms."
        )

        :timer.sleep(delay)

        process_sync_page_with_retry(
          page,
          page_size,
          last_sync_date,
          mode,
          max_attempts,
          attempts + 1
        )

      {:error, :rate_limit, page} when attempts < max_attempts ->
        delay = backoff_with_jitter(attempts)

        Logger.warning(
          "Rate limit syncing page #{page} (attempt #{attempts + 1}/#{max_attempts}), retrying in #{delay}ms."
        )

        :timer.sleep(delay)

        process_sync_page_with_retry(
          page,
          page_size,
          last_sync_date,
          mode,
          max_attempts,
          attempts + 1
        )

      {:error, type, page} ->
        Logger.error("Failed to sync page #{page} after #{max_attempts} attempts: #{type}")
        {:error, type, page}
    end
  end

  defp backoff_with_jitter(attempts) do
    base_delay = :math.pow(2, attempts) * 100
    jitter = :rand.uniform(100)
    round(base_delay + jitter)
  end
end
