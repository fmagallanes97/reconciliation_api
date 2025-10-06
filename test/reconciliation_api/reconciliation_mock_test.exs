defmodule ReconciliationApi.ReconciliationMockTest do
  use ExUnit.Case

  alias ReconciliationApi.Reconciliation
  alias ReconciliationApi.Persistence.Schema.Transaction

  @moduletag :mock

  setup do
    :meck.new(ReconciliationApi.Api, [:passthrough])
    :meck.new(ReconciliationApi.Repo, [:passthrough])
    on_exit(fn -> :meck.unload() end)
    :ok
  end

  test "find_match/1 returns {:ok, ext_tx} when external match exists" do
    :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
      {:ok,
       %{
         "data" => [
           %{
             "account_number" => "123",
             "amount" => "100.00",
             "currency" => "USD",
             "created_at" => "2025-09-21"
           }
         ]
       }}
    end)

    :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
      [
        %Transaction{
          account_number: "123",
          amount: Decimal.new("100.00"),
          currency: "USD",
          created_at: ~D[2025-09-21],
          occurrence_count: 1
        }
      ]
    end)

    params = %{
      account_number: "123",
      amount: Decimal.new("100.00"),
      created_at: ~D[2025-09-21],
      occurrence_count: 1
    }

    result = Reconciliation.find_match(params)
    assert {:ok, ext_tx} = result
    assert ext_tx["account_number"] == "123"
    assert ext_tx["amount"] == "100.00"
    assert ext_tx["currency"] == "USD"
    assert ext_tx["created_at"] == "2025-09-21"
  end

  test "find_match/1 returns {:error, :not_match} when no external match exists" do
    :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
      {:ok, %{"data" => []}}
    end)

    :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
      [
        %Transaction{
          account_number: "123",
          amount: Decimal.new("100.00"),
          currency: "USD",
          created_at: ~D[2025-09-21],
          occurrence_count: 1
        }
      ]
    end)

    params = %{
      account_number: "123",
      amount: Decimal.new("100.00"),
      created_at: ~D[2025-09-21],
      occurrence_count: 1
    }

    assert {:error, :not_found} = Reconciliation.find_match(params)
  end

  test "find_match/1 returns {:error, :not_found} when no internal match exists" do
    :meck.expect(ReconciliationApi.Repo, :all, fn _query -> [] end)

    params = %{
      account_number: "123",
      amount: Decimal.new("100.00"),
      created_at: ~D[2025-09-21],
      occurrence_count: 1
    }

    assert {:error, :not_found} = Reconciliation.find_match(params)
  end

  test "find_match/1 propagates API errors" do
    :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
      {:error, :timeout}
    end)

    :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
      [
        %Transaction{
          account_number: "123",
          amount: Decimal.new("100.00"),
          currency: "USD",
          created_at: ~D[2025-09-21],
          occurrence_count: 1
        }
      ]
    end)

    params = %{
      account_number: "123",
      amount: Decimal.new("100.00"),
      created_at: ~D[2025-09-21],
      occurrence_count: 1
    }

    assert {:error, :timeout} = Reconciliation.find_match(params)
  end
end
