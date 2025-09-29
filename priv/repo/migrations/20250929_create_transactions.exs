defmodule TransactionApi.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :account_number, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, null: false
      add :created_at, :date, null: false
      add :status, :string, null: false
    end

    create unique_index(:transactions, [:account_number, :amount, :created_at])
  end
end
