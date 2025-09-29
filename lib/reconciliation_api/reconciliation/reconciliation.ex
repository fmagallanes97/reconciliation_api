defmodule TransactionApi.Conciliation do
  alias TransactionApi.Mock.ExternalApi.ExternalApiMock, as: ExternalApi
  # Filter unique transactions by amount and created_at
  def unique_transactions(transactions) do
    transactions
    |> Enum.uniq_by(fn tx -> {tx["amount"], tx["created_at"]} end)
  end

  # For repeated transactions, take only the first for each (amount, created_at)
  def first_transactions(transactions) do
    transactions
    |> Enum.group_by(fn tx -> {tx["amount"], tx["created_at"]} end)
    |> Enum.map(fn {_key, txs} -> List.first(txs) end)
  end

  def get_transactions(page \\ 1, page_size \\ 100) do
    json =
      TransactionApi.Mock.ExternalApi.ExternalApiMock.fetch_transactions_json(page, page_size)

    Jason.decode!(json)["data"]
  end

  def sync_external_transactions(page \\ 1, page_size \\ 100) do
    external = ExternalApi.fetch_transactions_json(page, page_size)
    transactions = Jason.decode!(external)["data"]

    Enum.each(transactions, fn tx ->
      attrs = %{
        account_number: tx["account_number"],
        amount: Decimal.new(tx["amount"]),
        currency: tx["currency"],
        created_at: Date.from_iso8601!(tx["created_at"]),
        status: tx["status"]
      }

      %TransactionApi.Schema.Transaction{}
      |> ReconciliationApi.Schema.Transaction.changeset(attrs)
      |> ReconciliationApi.Repo.insert(on_conflict: :nothing)
    end)
  end
end
