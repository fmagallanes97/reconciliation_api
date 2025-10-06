defmodule ReconciliationApi.Reconciliation do
  @moduledoc """
    Module for reconciling transactions from an external API with the local database.
  """

  alias ReconciliationApi.Persistence.Mapper.TransactionMapper
  alias ReconciliationApi.Persistence.Schema.Transaction
  alias ReconciliationApi.Repo
  alias ReconciliationApi.Api

  require Logger

  import Ecto.Query

  @type query_params :: %{
          required(:account_number) => String.t(),
          required(:amount) => Decimal.t(),
          optional(:created_at) => DateTime.t(),
          optional(:occurrence_count) => integer
        }

  @type tx_key ::
          {account_number :: String.t(), amount :: String.t(), currency :: String.t(),
           created_at :: String.t()}

  @doc """
  Filters unique transactions by amount and created_at.
  """
  @spec unique_transactions([map()]) :: [map()]

  def unique_transactions(transactions) do
    transactions
    |> Enum.uniq_by(fn tx -> {tx["amount"], tx["created_at"]} end)
  end

  @doc """
  For repeated transactions, takes only the first for each (amount, created_at).
  """
  @spec first_transactions([map()]) :: [map()]

  def first_transactions(transactions) do
    transactions
    |> Enum.group_by(fn tx -> {tx["amount"], tx["created_at"]} end)
    |> Enum.map(fn {_key, txs} -> List.first(txs) end)
  end

  @doc """
  Finds transactions by account_number, amount, and optionally created_at and occurrence_count.
  """
  @spec find_transactions(query_params()) ::
          {:ok, [Transaction.t()]}
          | {:error,
             :missing_account_number | :missing_amount | :missing_account_number_and_amount}

  def find_transactions(%{account_number: _, amount: _} = query_params) do
    filter_keys = [:account_number, :amount, :created_at, :occurrence_count]

    where_clause =
      Enum.reduce(filter_keys, true, fn key, dyn ->
        case Map.get(query_params, key) do
          nil -> dyn
          value -> dynamic([t], ^dyn and field(t, ^key) == ^value)
        end
      end)

    query = from(t in Transaction, where: ^where_clause)

    {:ok, Repo.all(query)}
  end

  def find_transactions(%{amount: _}), do: {:error, :missing_account_number}
  def find_transactions(%{account_number: _}), do: {:error, :missing_amount}
  def find_transactions(_), do: {:error, :missing_account_number_and_amount}

  @doc """
  Gets the last synchronization date from the transactions table.
  """
  @spec get_last_sync_date() :: Date.t()

  def get_last_sync_date do
    from(t in Transaction,
      order_by: [desc: t.created_at],
      limit: 1,
      select: t.created_at
    )
    |> Repo.one() || ~D[1970-01-01]
  end

  @doc """
  Reports external transactions that are missing in the internal database.
  """
  @spec report_missing_internal([map()]) :: [tx_key()]

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

    {min_date, max_date} =
      external_keys
      |> Enum.map(&elem(&1, 3))
      |> Enum.min_max()

    db_transactions =
      from(t in Transaction,
        where: t.created_at >= ^min_date and t.created_at <= ^max_date,
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

  @doc """
  Reports transactions present in the internal database that are missing from the external data.
  Highlights inconsistencies where internal records have no corresponding external entry.
  """
  @spec report_missing_external([map()]) :: [Transaction.t()]

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

  @doc """
  Audits missing occurrences of transactions by comparing external and internal counts.
  """
  @spec audit_missing_occurrences([map()]) :: [{tx_key(), missing_occurrence :: integer()}]

  def audit_missing_occurrences(external_transactions) do
    external_counts =
      external_transactions
      |> Enum.frequencies_by(fn tx ->
        {tx["account_number"], tx["amount"], tx["currency"], tx["created_at"]}
      end)

    db_counts =
      Transaction
      |> Repo.all()
      |> Enum.frequencies_by(fn tx ->
        {tx.account_number, Decimal.to_string(tx.amount), tx.currency,
         Date.to_iso8601(tx.created_at)}
      end)

    for {key, ext_count} <- external_counts,
        db_count = Map.get(db_counts, key, 0),
        ext_count > db_count,
        do: {key, ext_count - db_count}
  end

  @doc """
  Finds a transaction by first searching the internal database using the given query parameters.
  If found, attempts to match the transaction with the external source based on occurrence count.
  Returns the matched transaction or an error if no match is found in either source.
  """
  @spec find_match(query_params()) ::
          {:ok, map()}
          | {:error, :not_found | :not_match | any()}

  def find_match(
        %{account_number: _, amount: _, occurrence_count: occurrence_count} = query_params
      ) do
    Logger.debug("find_match: query_params=#{inspect(query_params)}")

    with {:ok, [tx_struct | _]} <- find_transactions(query_params),
         {:ok, target_tx} <- TransactionMapper.from_struct(tx_struct),
         {:ok, match_tx} <- find_nth_match_across_pages(target_tx, occurrence_count) do
      {:ok, match_tx}
    else
      {:ok, []} -> {:error, :not_found}
      {:error, :not_found} = e -> e
      {:error, _reason} = e -> e
    end
  end

  # Private

  defp find_nth_match_across_pages(target_tx, occurrence_count, page \\ 1, match_count \\ 0) do
    case Api.fetch_transactions(page, 100) do
      {:ok, %{data: []}} ->
        {:error, :not_found}

      {:ok, %{data: page_data}} ->
        normalized_target = normalize(target_tx)
        predicate = &matches_tx?(normalize(&1), normalized_target)

        case nth_match(page_data, predicate, occurrence_count - match_count) do
          {:ok, tx_match, _} ->
            {:ok, tx_match}

          {:error, :not_found, matches_in_page} ->
            find_nth_match_across_pages(
              target_tx,
              occurrence_count,
              page + 1,
              match_count + matches_in_page
            )
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp nth_match(enum, predicate, n) do
    stream = Stream.filter(enum, predicate)
    matches = Enum.to_list(stream)

    case Enum.at(matches, n - 1) do
      nil -> {:error, :not_found, length(matches)}
      item -> {:ok, item, length(matches)}
    end
  end

  defp matches_tx?(
         %{account_number: acc, amount: amt, currency: curr, created_at: date},
         %{account_number: acc, amount: amt, currency: curr, created_at: date}
       ),
       do: true

  defp matches_tx?(_, _), do: false

  defp normalize(tx) do
    %{
      account_number: to_string(tx[:account_number] || tx["account_number"]),
      amount: Decimal.new(tx[:amount] || tx["amount"]),
      currency: to_string(tx[:currency] || tx["currency"]),
      created_at:
        case tx[:created_at] || tx["created_at"] do
          %Date{} = date -> date
          date_str when is_binary(date_str) -> Date.from_iso8601!(date_str)
        end
    }
  end
end
