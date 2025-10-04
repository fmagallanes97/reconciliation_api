defmodule ReconciliationApi.Repo.Migrations.DropOldTransactionUniqueIndex do
  use Ecto.Migration

  def change do
    drop_if_exists index(:transactions, [:account_number, :amount, :created_at])
  end
end
