defmodule ReconciliationApi.ReconciliationMockTest do
  use ExUnit.Case

  alias ReconciliationApi.Reconciliation
  alias ReconciliationApi.Persistence.Schema.Transaction

  @moduletag :mock

  setup do
    :meck.new(ReconciliationApi.Api, [:passthrough])
    :meck.new(ReconciliationApi.Repo, [:passthrough])

    on_exit(fn ->
      :meck.unload()
      # stop the mock genserver if running
      if Process.whereis(TransactionApi.Mock.ExternalApi.ExternalApiMock) do
        GenServer.stop(TransactionApi.Mock.ExternalApi.ExternalApiMock)
      end
    end)

    :ok
  end

  describe "find_match/1 normalization and matching" do
    test "normalizes string-keyed map and matches" do
      :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
        {:ok,
         %{
           data: [
             %{account_number: "123", amount: "100.00", currency: "USD", created_at: "2024-06-01"}
           ]
         }}
      end)

      :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
        [
          %Transaction{
            account_number: "123",
            amount: Decimal.new("100.00"),
            currency: "USD",
            created_at: ~D[2024-06-01],
            occurrence_count: 1
          }
        ]
      end)

      params = %{
        account_number: "123",
        amount: Decimal.new("100.00"),
        created_at: ~D[2024-06-01],
        occurrence_count: 1
      }

      result = Reconciliation.find_match(params)
      assert {:ok, ext_tx} = result
      assert ext_tx.account_number == "123"
      assert ext_tx.amount == "100.00"
      assert ext_tx.currency == "USD"
      assert ext_tx.created_at == "2024-06-01"
    end

    test "normalizes atom-keyed map and matches" do
      :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
        {:ok,
         %{
           data: [
             %{
               account_number: "456",
               amount: "200.50",
               currency: "EUR",
               created_at: ~D[2024-06-02]
             }
           ]
         }}
      end)

      :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
        [
          %Transaction{
            account_number: "456",
            amount: Decimal.new("200.50"),
            currency: "EUR",
            created_at: ~D[2024-06-02],
            occurrence_count: 1
          }
        ]
      end)

      params = %{
        account_number: "456",
        amount: Decimal.new("200.50"),
        created_at: ~D[2024-06-02],
        occurrence_count: 1
      }

      result = Reconciliation.find_match(params)
      assert {:ok, ext_tx} = result
      assert ext_tx.account_number == "456"
      assert ext_tx.amount == "200.50"
      assert ext_tx.currency == "EUR"
      assert ext_tx.created_at == ~D[2024-06-02]
    end

    test "handles mixed keys and types" do
      :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
        {:ok,
         %{
           data: [
             %{account_number: "789", amount: "300", currency: "GBP", created_at: "2024-06-03"}
           ]
         }}
      end)

      :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
        [
          %Transaction{
            account_number: "789",
            amount: Decimal.new("300"),
            currency: "GBP",
            created_at: ~D[2024-06-03],
            occurrence_count: 1
          }
        ]
      end)

      params = %{
        account_number: "789",
        amount: Decimal.new("300"),
        created_at: ~D[2024-06-03],
        occurrence_count: 1
      }

      result = Reconciliation.find_match(params)
      assert {:ok, ext_tx} = result
      assert ext_tx.account_number == "789"
      assert ext_tx.amount == "300"
      assert ext_tx.currency == "GBP"
      assert ext_tx.created_at == "2024-06-03"
    end
  end

  describe "find_match/1 matching logic" do
    test "returns false for different transactions" do
      :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn
        1, _size ->
          {:ok,
           %{
             data: [
               %{
                 account_number: "999",
                 amount: "999.99",
                 currency: "USD",
                 created_at: "2024-06-01"
               }
             ]
           }}

        _, _size ->
          {:ok, %{data: []}}
      end)

      :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
        [
          %Transaction{
            account_number: "123",
            amount: Decimal.new("100.00"),
            currency: "USD",
            created_at: ~D[2024-06-01],
            occurrence_count: 1
          }
        ]
      end)

      params = %{
        account_number: "123",
        amount: Decimal.new("100.00"),
        created_at: ~D[2024-06-01],
        occurrence_count: 1
      }

      assert {:error, :not_found} = Reconciliation.find_match(params)
    end
  end

  describe "find_match/1 nth occurrence logic" do
    test "finds nth occurrence" do
      :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn
        1, _size ->
          {:ok,
           %{
             data: [
               %{account_number: "1", amount: "10.00", currency: "USD", created_at: "2024-06-01"},
               %{account_number: "2", amount: "20.00", currency: "USD", created_at: "2024-06-01"},
               %{account_number: "1", amount: "10.00", currency: "USD", created_at: "2024-06-01"},
               %{account_number: "1", amount: "10.00", currency: "USD", created_at: "2024-06-01"}
             ]
           }}

        _, _size ->
          {:ok, %{data: []}}
      end)

      :meck.expect(ReconciliationApi.Repo, :all, fn _query ->
        [
          %Transaction{
            account_number: "1",
            amount: Decimal.new("10.00"),
            currency: "USD",
            created_at: ~D[2024-06-01],
            occurrence_count: 2
          }
        ]
      end)

      params = %{
        account_number: "1",
        amount: Decimal.new("10.00"),
        created_at: ~D[2024-06-01],
        occurrence_count: 3
      }

      result = Reconciliation.find_match(params)
      assert {:ok, ext_tx} = result
      assert ext_tx.account_number == "1"
      assert ext_tx.amount == "10.00"
      assert ext_tx.currency == "USD"
      assert ext_tx.created_at == "2024-06-01"
    end
  end

  describe "find_match/1 error paths" do
    test "returns {:error, :not_found} when no external match exists" do
      :meck.expect(ReconciliationApi.Api, :fetch_transactions, fn _page, _size ->
        {:ok, %{data: []}}
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

    test "returns {:error, :not_found} when no internal match exists" do
      :meck.expect(ReconciliationApi.Repo, :all, fn _query -> [] end)

      params = %{
        account_number: "123",
        amount: Decimal.new("100.00"),
        created_at: ~D[2025-09-21],
        occurrence_count: 1
      }

      assert {:error, :not_found} = Reconciliation.find_match(params)
    end

    test "propagates API errors" do
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
end
