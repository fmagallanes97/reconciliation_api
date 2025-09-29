defmodule TransactionApi.Mock.ExternalApi.ExternalApiMock do
  @moduledoc """
  Simulates an external API that returns paginated JSON responses for transactions.
  """

  @total_transactions 1000

  # Generates a list of transactions with timestamps spaced by minutes
  defp generate_transactions do
    now = DateTime.utc_now()
    Enum.map(1..@total_transactions, fn i ->
      %{
        account_number: "ACC#{1000 + i}",
        amount: Float.round(:rand.uniform() * 1000, 2),
        currency: "USD",
        created_at: DateTime.add(now, -i * 60, :second) |> DateTime.to_date() |> Date.to_iso8601(),
        status: "finished"
      }
    end)
  end

  @doc """
  Returns a paginated JSON string of transactions, simulating an external API response.

  ## Parameters

    - page: The page number (1-based).
    - page_size: The number of transactions per page.

  ## Example

      iex> TransactionApi.Mock.ExternalApi.ExternalApiMock.fetch_transactions_json(1, 100)
      "{\\"data\\":[...],\\"page\\":1,\\"page_size\\":100,\\"total\\":1000}"

  """
  def fetch_transactions_json(page \\ 1, page_size \\ 100) do
    transactions = generate_transactions()
    start_idx = (page - 1) * page_size
    paginated = transactions |> Enum.slice(start_idx, page_size)

    response = %{
      data: paginated,
      page: page,
      page_size: page_size,
      total: @total_transactions
    }

    Jason.encode!(response)
  end
end