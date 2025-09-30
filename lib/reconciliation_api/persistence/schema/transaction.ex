defmodule ReconciliationApi.Persistence.Schema.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          account_number: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          created_at: Date.t(),
          status: String.t()
        }

  @primary_key false
  schema "transactions" do
    field(:account_number, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:created_at, :date)
    field(:status, :string)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:account_number, :amount, :currency, :created_at, :status])
    |> validate_required([:account_number, :amount, :currency, :created_at, :status])
    |> unique_constraint([:account_number, :amount, :currency, :created_at])
  end
end
