defmodule ReconciliationApi.Repo.Migrations.AddOccurrenceCountTrigger do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION set_occurrence_count()
    RETURNS trigger AS $$
    BEGIN
      NEW.occurrence_count := (
        SELECT COALESCE(MAX(occurrence_count), 0) + 1
        FROM transactions
        WHERE account_number = NEW.account_number
          AND amount = NEW.amount
          AND currency = NEW.currency
          AND created_at = NEW.created_at
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER trg_set_occurrence_count
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION set_occurrence_count();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS trg_set_occurrence_count ON transactions;")
    execute("DROP FUNCTION IF EXISTS set_occurrence_count();")
  end
end
