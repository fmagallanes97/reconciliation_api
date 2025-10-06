defmodule ReconciliationApi.ReconciliationTest do
  use ExUnit.Case

  alias ReconciliationApi.Reconciliation

  @moduletag :unit

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

  describe "normalize/1" do
    test "normalizes string-keyed map" do
      tx = %{
        "account_number" => "123",
        "amount" => "100.00",
        "currency" => "USD",
        "created_at" => "2024-06-01"
      }

      norm = Reconciliation.normalize(tx)
      assert norm.account_number == "123"
      assert norm.amount == Decimal.new("100.00")
      assert norm.currency == "USD"
      assert norm.created_at == ~D[2024-06-01]
    end

    test "normalizes atom-keyed map" do
      tx = %{
        account_number: "456",
        amount: "200.50",
        currency: "EUR",
        created_at: ~D[2024-06-02]
      }

      norm = Reconciliation.normalize(tx)
      assert norm.account_number == "456"
      assert norm.amount == Decimal.new("200.50")
      assert norm.currency == "EUR"
      assert norm.created_at == ~D[2024-06-02]
    end

    test "handles mixed keys and types" do
      tx = %{
        "account_number" => 789,
        "amount" => 300,
        "currency" => :GBP,
        "created_at" => "2024-06-03"
      }

      norm = Reconciliation.normalize(tx)
      assert norm.account_number == "789"
      assert norm.amount == Decimal.new("300")
      assert norm.currency == "GBP"
      assert norm.created_at == ~D[2024-06-03]
    end
  end

  describe "matches_tx?/2" do
    test "returns true for normalized identical transactions" do
      tx1 = %{
        account_number: "123",
        amount: Decimal.new("100.00"),
        currency: "USD",
        created_at: ~D[2024-06-01]
      }

      tx2 = %{
        account_number: "123",
        amount: Decimal.new("100.00"),
        currency: "USD",
        created_at: ~D[2024-06-01]
      }

      assert Reconciliation.matches_tx?(tx1, tx2)
    end

    test "returns false for different transactions" do
      tx1 = %{
        account_number: "123",
        amount: Decimal.new("100.00"),
        currency: "USD",
        created_at: ~D[2024-06-01]
      }

      tx2 = %{
        account_number: "124",
        amount: Decimal.new("100.00"),
        currency: "USD",
        created_at: ~D[2024-06-01]
      }

      refute Reconciliation.matches_tx?(tx1, tx2)
    end

    test "returns false if not normalized" do
      tx1 = %{
        "account_number" => "123",
        "amount" => "100.00",
        "currency" => "USD",
        "created_at" => "2024-06-01"
      }

      tx2 = %{
        "account_number" => "123",
        "amount" => "100.00",
        "currency" => "USD",
        "created_at" => "2024-06-01"
      }

      refute Reconciliation.matches_tx?(tx1, tx2)
    end

    test "returns true after normalization" do
      tx1 = %{
        "account_number" => "123",
        "amount" => "100.00",
        "currency" => "USD",
        "created_at" => "2024-06-01"
      }

      tx2 = %{
        "account_number" => "123",
        "amount" => "100.00",
        "currency" => "USD",
        "created_at" => "2024-06-01"
      }

      norm1 = Reconciliation.normalize(tx1)
      norm2 = Reconciliation.normalize(tx2)
      assert Reconciliation.matches_tx?(norm1, norm2)
    end
  end

  describe "nth_match/3" do
    setup do
      txs = [
        %{
          account_number: "1",
          amount: Decimal.new("10.00"),
          currency: "USD",
          created_at: ~D[2024-06-01]
        },
        %{
          account_number: "2",
          amount: Decimal.new("20.00"),
          currency: "USD",
          created_at: ~D[2024-06-01]
        },
        %{
          account_number: "1",
          amount: Decimal.new("10.00"),
          currency: "USD",
          created_at: ~D[2024-06-01]
        },
        %{
          account_number: "1",
          amount: Decimal.new("10.00"),
          currency: "USD",
          created_at: ~D[2024-06-01]
        }
      ]

      %{txs: txs}
    end

    test "finds the nth occurrence and total matches", %{txs: txs} do
      pred = fn tx -> tx.account_number == "1" and tx.amount == Decimal.new("10.00") end
      assert {:ok, match, 3} = Reconciliation.nth_match(txs, pred, 2)
      assert match.account_number == "1"
      assert match.amount == Decimal.new("10.00")
    end

    test "returns error if nth occurrence not found", %{txs: txs} do
      pred = fn tx -> tx.account_number == "1" and tx.amount == Decimal.new("10.00") end
      assert {:error, :not_found, 3} = Reconciliation.nth_match(txs, pred, 5)
    end

    test "returns error and zero if no matches" do
      txs = [
        %{
          account_number: "2",
          amount: Decimal.new("20.00"),
          currency: "USD",
          created_at: ~D[2024-06-01]
        }
      ]

      pred = fn tx -> tx.account_number == "1" end
      assert {:error, :not_found, 0} = Reconciliation.nth_match(txs, pred, 1)
    end
  end
end
