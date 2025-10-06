defmodule Mix.Tasks.Reconciliation.AuditMissing do
  use Mix.Task

  @shortdoc "Batch audit: reports transactions missing in the internal DB compared to the external API"

  @moduledoc """
  Batch audit for missing transactions.

  This task fetches a batch of external transactions and compares them to your internal database,
  reporting any transactions that are present externally but missing internally (including duplicates).

  ## Usage

      mix reconciliation.audit_missing

  You will be prompted for page number and page size for the external API fetch.
  """

  alias ReconciliationApi.Api
  alias ReconciliationApi.Reconciliation

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("""
    === Audit Missing ===
    This audit checks for transactions that exist in the external source but are missing from your internal system.
    """)

    IO.puts("Last sync in the system date: #{Reconciliation.get_last_sync_date()}")
    IO.puts("Note: Type 'q', 'exit', or press Ctrl+D at any prompt to quit.")

    page =
      prompt("Enter page number to fetch (default 1): ")
      |> parse_int(1)

    page_size =
      prompt("Enter page size (default 100): ")
      |> parse_int(100)

    IO.puts("\nFetching external transactions (page #{page}, size #{page_size})...")

    external_data =
      case Api.fetch_transactions(page, page_size) do
        {:ok, %{"data" => data}} ->
          data

        {:error, reason} ->
          IO.puts("Failed to fetch external transactions: #{inspect(reason)}")
          []
      end

    missing_occurrences = Reconciliation.audit_missing_occurrences(external_data)
    count = Enum.reduce(missing_occurrences, 0, fn {_key, missing}, acc -> acc + missing end)
    IO.puts("\nFound #{count} missing transaction occurrences in internal database.")

    if count > 0 do
      show_details =
        prompt("Show details of missing occurrences? (y/n): ")
        |> String.downcase()

      if show_details == "y" do
        Enum.each(missing_occurrences, fn {key, missing} ->
          IO.puts("#{inspect(key)} is missing #{missing} occurrence(s)")
        end)
      else
        IO.puts("Details skipped.")
      end
    else
      IO.puts("All external transaction occurrences are present in the internal system.")
    end
  end

  defp prompt(message) do
    input = IO.gets(message)

    case input do
      :eof ->
        IO.puts("\nExiting.")
        System.halt(0)

      s ->
        trimmed = String.trim(s)

        if trimmed in ["q", "exit"] do
          IO.puts("Exiting.")
          System.halt(0)
        else
          trimmed
        end
    end
  end

  defp parse_int(s, default) do
    case Integer.parse(String.trim(s)) do
      {num, _} -> num
      :error -> default
    end
  end
end
