defmodule ReconciliationApi.Sync do
  @moduledoc """
  Synchronizes transactions from the external API into the database.
  Supports incremental and full sync modes, batching, and retry logic.

  ## Options

    * `:page_size` - Number of transactions per page (default: 100)
    * `:pages_to_check` - Number of pages to check (default: 3)
    * `:concurrency` - Number of concurrent workers (default: 4)
    * `:max_attempts` - Max retry attempts per page (default: 3)
    * `:mode` - Sync mode (default: `:incremental`)
        * `:incremental` - Only fetches new transactions since the last sync (faster).
        * `:full` - Deep scan; fetches all transactions from the beginning (slower, more thorough).
  """

  alias ReconciliationApi.Api
  alias ReconciliationApi.Persistence.Schema.Transaction
  alias ReconciliationApi.Repo
  alias ReconciliationApi.Reconciliation

  import ReconciliationApi.Util.Retry, only: [retry: 3, retryable_error?: 1]

  require Logger

  @type opt ::
          {:page_size, pos_integer()}
          | {:pages_to_check, pos_integer()}
          | {:concurrency, pos_integer()}
          | {:max_attempts, pos_integer()}
          | {:mode, :incremental | :full}

  @type opts :: [opt]

  def concurrent_sync(opts) do
    %{
      page_size: page_size,
      pages_to_check: pages_to_check,
      mode: mode,
      concurrency: concurrency,
      max_attempts: max_attempts
    } = parse_opts(opts)

    case Api.fetch_transactions(1, page_size) do
      {:ok, data} ->
        total_pages = data["total_pages"]
        start_page = start_page(total_pages, pages_to_check, mode)
        last_sync_date = Reconciliation.get_last_sync_date()

        page_worker = fn page ->
          retry(
            fn -> process_and_batch(page, page_size, last_sync_date, mode) end,
            max_attempts,
            &retryable_error?/1
          )
        end

        Task.Supervisor.async_stream(
          ReconciliationApi.SyncSupervisor,
          start_page..total_pages,
          page_worker,
          max_concurrency: concurrency,
          timeout: :infinity
        )
        |> Enum.to_list()

      {:error, _reason} = e ->
        e
    end
  end

  # Private

  defp parse_opts(opts) do
    opts
    |> Enum.into(%{})
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:pages_to_check, 3)
    |> Map.put_new(:concurrency, 4)
    |> Map.put_new(:max_attempts, 3)
    |> Map.put_new(:mode, :incremental)
    |> then(fn map ->
      case map.mode do
        :full -> %{map | pages_to_check: 100_000}
        _ -> map
      end
    end)
  end

  defp start_page(_, _, :full), do: 1
  defp start_page(total_pages, pages_to_check, _), do: max(total_pages - pages_to_check + 1, 1)

  defp process_and_batch(page, page_size, last_sync_date, mode) do
    case process_single(page, page_size, last_sync_date, mode) do
      {:ok, transactions} -> in_batch(transactions, page)
      error -> error
    end
  end

  defp process_single(page, page_size, last_sync_date, :incremental) do
    case Api.fetch_transactions(page, page_size) do
      {:ok, %{data: data}} ->
        new_transactions =
          Enum.filter(data, fn tx ->
            Date.from_iso8601!(tx["created_at"]) > last_sync_date
          end)

        {:ok, new_transactions}

      {:error, _reason} = e ->
        e
    end
  end

  defp process_single(page, page_size, _, :full) do
    case Api.fetch_transactions(page, page_size) do
      {:ok, %{data: data}} ->
        {:ok, data}

      {:error, _reason} = e ->
        e
    end
  end

  defp in_batch([], page) do
    Logger.info("No new records to insert for page #{page}.")
    {:ok, []}
  end

  defp in_batch(transactions, page) do
    batch_attrs =
      Enum.map(transactions, fn tx ->
        %{
          account_number: tx["account_number"],
          amount: Decimal.new(tx["amount"]),
          currency: tx["currency"],
          created_at: Date.from_iso8601!(tx["created_at"]),
          status: tx["status"]
        }
      end)

    Repo.insert_all(Transaction, batch_attrs, on_conflict: :nothing)
    Logger.info("Inserted #{length(batch_attrs)} new records from page #{page}.")
    {:ok, batch_attrs}
  end
end
