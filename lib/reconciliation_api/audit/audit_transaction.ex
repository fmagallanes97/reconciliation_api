defmodule ReconciliationApi.AuditTransaction do
  @moduledoc """
  Interactive audit for a single transaction.
  """

  alias ReconciliationApi.Reconciliation

  def run_interactive do
    IO.puts("""
    === Audit Transaction ===
    This interactive audit allows you to search for a transaction in your internal system and reconcile it with the external source.
    """)

    IO.puts("Note: Type 'q', 'exit', or press Ctrl+D at any prompt to quit.")

    # Prompt for search criteria
    account_number = prompt("Account number: ")
    amount = prompt("Amount: ")
    date = prompt("Date (YYYY-MM-DD): ")

    query_params =
      %{}
      |> maybe_put(:account_number, account_number)
      |> maybe_put(:amount, amount)
      |> maybe_put(:created_at, date)

    case Reconciliation.find_transactions(query_params) do
      {:ok, []} ->
        IO.puts("No transactions found with those criteria in the internal database.")

      {:ok, transactions} ->
        limited = Enum.take(transactions, 20)

        IO.puts("\nMatching transactions in internal database (showing up to 20):")

        Enum.with_index(limited, 1)
        |> Enum.each(fn {tx, idx} ->
          IO.puts(
            "#{idx}) #{tx.account_number} | #{tx.amount} | #{tx.currency} | #{tx.created_at} | occurrence: #{tx.occurrence_count}"
          )
        end)

        pick =
          prompt("Pick a transaction by number (1-#{length(limited)}): ")
          |> parse_int(1)

        if pick < 1 or pick > length(limited) do
          IO.puts("Invalid selection.")
        else
          tx = Enum.at(limited, pick - 1)

          params = %{
            account_number: tx.account_number,
            amount: tx.amount,
            created_at: tx.created_at,
            occurrence_count: tx.occurrence_count
          }

          IO.puts("\nReconciling selected transaction with external source...")
          result = Reconciliation.find_match(params)
          IO.puts("\nReconciliation result:")
          result
        end

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, :amount, value), do: Map.put(map, :amount, Decimal.new(value))

  defp maybe_put(map, :created_at, value),
    do: Map.put(map, :created_at, Date.from_iso8601!(value))

  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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

  defp parse_int(str, default) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> default
    end
  end
end
