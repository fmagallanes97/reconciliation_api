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

    IO.puts("Running reconciliation report...")
    missing_in_db = ReconciliationApi.Reconciliation.report_missing_internal(external_data)

    count = length(missing_in_db)
    IO.puts("\nFound #{count} missing transactions in internal DB.")

    if count > 0 do
      show_details =
        IO.gets("Show details of missing transactions? (y/n): ")
        |> String.trim()
        |> String.downcase()

      if show_details == "y" do
        Enum.each(missing_in_db, fn tx ->
          IO.inspect(tx)
        end)
      else
        IO.puts("Details skipped.")
      end
    else
      IO.puts("All external transactions are present in the internal DB.")
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
