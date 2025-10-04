defmodule Reconciliation.CLI.Reconciliation do
  @moduledoc """
  Interactive CLI for reconciliation: reports transactions missing in the internal DB.
  """

  def run_cli do
    Logger.configure(level: :error)

    IO.puts("""
    === Reconciliation CLI ===

    This tool compares external transactions (from an external source) with your internal database.
    Reconciliation means checking both sources of truth to find transactions that exist externally but are missing internally.

    You can choose which batch (page) of transactions to check, and how many per batch:

    - Page number: Which batch of transactions to fetch (1 = first batch, 2 = second, etc.)
    - Page size: How many transactions per batch (e.g., 100)
    """)

    page =
      IO.gets("Enter page number to fetch (default 1, e.g. 1 for first batch): ")
      |> parse_int(1)

    page_size =
      IO.gets("Enter page size (default 100, e.g. 100 transactions per batch): ")
      |> parse_int(100)

    IO.puts("\nFetching external transactions (page #{page}, size #{page_size})...")
    external_data = ReconciliationApi.Reconciliation.get_transactions(page, page_size)

    IO.puts("Running reconciliation report (including missing occurrences)...")

    # Count occurrences in external data
    external_counts =
      external_data
      |> Enum.frequencies_by(fn tx ->
        {tx["account_number"], tx["amount"], tx["currency"], tx["created_at"]}
      end)

    # Count occurrences in DB
    db_counts =
      ReconciliationApi.Persistence.Schema.Transaction
      |> ReconciliationApi.Repo.all()
      |> Enum.frequencies_by(fn tx ->
        {tx.account_number, Decimal.to_string(tx.amount), tx.currency,
         Date.to_iso8601(tx.created_at)}
      end)

    # Find keys where external count > db count
    missing_occurrences =
      for {key, ext_count} <- external_counts,
          db_count = Map.get(db_counts, key, 0),
          ext_count > db_count,
          do: {key, ext_count - db_count}

    count = Enum.reduce(missing_occurrences, 0, fn {_key, missing}, acc -> acc + missing end)
    IO.puts("\nFound #{count} missing transaction occurrences in internal DB.")

    if count > 0 do
      show_details =
        IO.gets("Show details of missing occurrences? (y/n): ")
        |> String.trim()
        |> String.downcase()

      if show_details == "y" do
        Enum.each(missing_occurrences, fn {key, missing} ->
          IO.puts("#{inspect(key)} is missing #{missing} occurrence(s)")
        end)
      else
        IO.puts("Details skipped.")
      end
    else
      IO.puts("All external transaction occurrences are present in the internal DB.")
    end
  end

  defp parse_int(input, default) do
    case input do
      :eof ->
        default

      s ->
        case Integer.parse(String.trim(s)) do
          {num, _} -> num
          :error -> default
        end
    end
  end
end

defmodule Mix.Tasks.ReconciliationAudit do
  use Mix.Task

  @shortdoc "Interactively reports transactions missing in the internal DB"

  def run(_args) do
    Mix.Task.run("app.start")
    Reconciliation.CLI.Reconciliation.run_cli()
  end
end
