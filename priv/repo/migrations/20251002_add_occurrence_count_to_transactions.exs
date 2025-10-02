defmodule ReconciliationApi.Repo.Migrations.AddOccurrenceCountToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :occurrence_count, :integer, null: false, default: 1
    end

    create unique_index(
      :transactions,
      [:account_number, :amount, :currency, :created_at, :occurrence_count],
      name: :unique_transaction_occurrence
    )
  end
end
