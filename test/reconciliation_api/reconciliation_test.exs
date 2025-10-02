defmodule ReconciliationApi.ReconciliationTest do
  use ExUnit.Case

  alias ReconciliationApi.Reconciliation

  describe "unique_transactions/1" do
    test "removes duplicate transactions by amount and created_at" do
      txs = [
        %{"amount" => "100.00", "created_at" => "2025-09-21"},
        %{"amount" => "100.00", "created_at" => "2025-09-21"},
        %{"amount" => "200.00", "created_at" => "2025-09-22"}
      ]

      uniq = Reconciliation.unique_transactions(txs)
      assert length(uniq) == 2
      assert Enum.any?(uniq, &(&1["amount"] == "100.00" && &1["created_at"] == "2025-09-21"))
      assert Enum.any?(uniq, &(&1["amount"] == "200.00" && &1["created_at"] == "2025-09-22"))
    end
  end

  describe "first_transactions/1" do
    test "keeps only the first transaction for each (amount, created_at)" do
      txs = [
        %{"amount" => "100.00", "created_at" => "2025-09-21", "id" => 1},
        %{"amount" => "100.00", "created_at" => "2025-09-21", "id" => 2},
        %{"amount" => "200.00", "created_at" => "2025-09-22", "id" => 3},
        %{"amount" => "200.00", "created_at" => "2025-09-22", "id" => 4}
      ]

      firsts = Reconciliation.first_transactions(txs)
      assert length(firsts) == 2
      assert Enum.any?(firsts, &(&1["id"] == 1))
      assert Enum.any?(firsts, &(&1["id"] == 3))
    end
  end

  describe "deduplicate_with_occurrence_count/1" do
    test "assigns occurrence_count for repeated transactions (FIFO)" do
      txs = [
        %{"account_number" => "A", "amount" => "100.00", "created_at" => "2025-09-21"},
        %{"account_number" => "A", "amount" => "100.00", "created_at" => "2025-09-21"},
        %{"account_number" => "A", "amount" => "100.00", "created_at" => "2025-09-21"},
        %{"account_number" => "B", "amount" => "200.00", "created_at" => "2025-09-22"},
        %{"account_number" => "B", "amount" => "200.00", "created_at" => "2025-09-22"}
      ]

      deduped = Reconciliation.deduplicate_with_occurrence_count(txs)

      # Check that all transactions have occurrence_count
      assert Enum.all?(deduped, &Map.has_key?(&1, "occurrence_count"))

      # Check correct occurrence_count assignment for group A
      a_group = Enum.filter(deduped, &(&1["account_number"] == "A"))
      assert Enum.map(a_group, & &1["occurrence_count"]) == [1, 2, 3]

      # Check correct occurrence_count assignment for group B
      b_group = Enum.filter(deduped, &(&1["account_number"] == "B"))
      assert Enum.map(b_group, & &1["occurrence_count"]) == [1, 2]
    end
  end
end
