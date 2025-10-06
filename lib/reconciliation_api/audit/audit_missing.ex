defmodule ReconciliationApi.AuditMissing do
  @moduledoc """
  Batch audit for missing transactions.
  """

  alias ReconciliationApi.Api
  alias ReconciliationApi.Reconciliation

  def run_interactive do
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
        {:ok, %{data: data}} ->
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
