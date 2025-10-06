defmodule ReconciliationApi.Persistence.Mapper.TransactionMapper do
  alias ReconciliationApi.Persistence.Schema.Transaction

  @type invalid_error :: {:error, :invalid_transaction}

  @doc """
  Normalizes a transaction struct into a map.

  Returns `{:ok, map}` if the input is a Transaction struct,
  or `{:error, :invalid_transaction}` otherwise.

  ## Examples

      iex> TransactionMapper.from_struct(%Transaction{
      ...>   account_number: "ACC1001",
      ...>   amount: Decimal.new("100.00"),
      ...>   currency: "USD",
      ...>   created_at: ~D[2025-10-01],
      ...>   occurrence_count: 2
      ...> })
      {:ok, %{
        account_number: "ACC1001",
        amount: Decimal.new("100.00"),
        currency: "USD",
        created_at: ~D[2025-10-01],
        occurrence_count: 2
      }}

      iex> TransactionMapper.from_struct(%{})
      {:error, :invalid_transaction}
  """
  @spec from_struct(Transaction.t() | any()) :: {:ok, map()} | invalid_error()

  def from_struct(%Transaction{} = tx) do
    {:ok,
     Map.take(Map.from_struct(tx), [
       :account_number,
       :amount,
       :currency,
       :created_at,
       :occurrence_count
     ])}
  end

  def from_struct(_), do: {:error, :invalid_transaction}
end
