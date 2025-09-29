transaction_api/lib/transaction_api/schema/transaction.ex
defmodule TransactionApi.Schema.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "transactions" do
    field :transaction_id, :string
    field :account_number, :string
    field :amount_usd, :decimal
    field :created_at, :date
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:transaction_id, :account_number, :amount_usd, :created_at])
    |> validate_required([:transaction_id, :account_number, :amount_usd, :created_at])
    |> unique_constraint(:transaction_id)
  end
end
