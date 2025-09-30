defmodule ReconciliationApi.Reconciliation do
  @moduledoc """
    Module for reconciling transactions from an external API with the local database.
  """

  alias ReconciliationApi.Persistence.Schema.Transaction
  alias TransactionApi.Mock.ExternalApi.ExternalApiMock, as: ExternalApi
  alias ReconciliationApi.Repo

  require Logger

  import Ecto.Query

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
    case ExternalApi.fetch_transactions(page, page_size) do
      %{"data" => data} ->
        data

      {:error, reason} ->
        Logger.error("Error fetching transactions for page #{page}: #{inspect(reason)}")
        []
    end
  end

  def get_last_sync_date do
    from(t in Transaction,
      order_by: [desc: t.created_at],
      limit: 1,
      select: t.created_at
    )
    |> Repo.one() || ~D[1970-01-01]
  end

  def report_missing_internal(external_transactions) do
    external_keys =
      Enum.map(external_transactions, fn tx ->
        {
          tx["account_number"],
          Decimal.new(tx["amount"]),
          tx["currency"],
          Date.from_iso8601!(tx["created_at"])
        }
      end)

    dynamic_conditions =
      Enum.reduce(external_keys, false, fn {account, amount, currency, date}, dyn ->
        dynamic(
          [t],
          ^dyn or
            (t.account_number == ^account and
               t.amount == ^amount and
               t.currency == ^currency and
               t.created_at == ^date)
        )
      end)

    db_transactions =
      from(t in Transaction,
        where: ^dynamic_conditions,
        select: {t.account_number, t.amount, t.currency, t.created_at}
      )
      |> Repo.all()
      |> MapSet.new()

    Enum.filter(external_transactions, fn tx ->
      key = {
        tx["account_number"],
        Decimal.new(tx["amount"]),
        tx["currency"],
        Date.from_iso8601!(tx["created_at"])
      }

      not MapSet.member?(db_transactions, key)
    end)
  end

  def report_missing_external(external_transactions) do
    external_keys =
      MapSet.new(
        Enum.map(external_transactions, fn tx ->
          {tx["account_number"], Decimal.new(tx["amount"]), tx["currency"],
           Date.from_iso8601!(tx["created_at"])}
        end)
      )

    Transaction
    |> Repo.all()
    |> Enum.filter(fn t ->
      not MapSet.member?(external_keys, {t.account_number, t.amount, t.currency, t.created_at})
    end)
  end
end
