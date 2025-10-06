defmodule ReconciliationApi.Api do
  @moduledoc """
  HTTP-client-agnostic interface for fetching transactions from an external service.
  By default, uses a mock implementation that simulates HTTP responses, but can be swapped for a real HTTP client.
  """

  alias TransactionApi.Mock.ExternalApi.ExternalApiMock

  @type on_success :: {:ok, map()}
  @type on_failure :: {:error, atom()}

  @doc """
  Fetch transactions from the external API (mock by default).

  Returns:
    - `on_success` (`{:ok, map}`) on success (decoded JSON response)
    - `on_failure` (`{:error, reason}`) on failure (reason is an atom, e.g. `:timeout`, `:rate_limit`, `:api_failure`)
  """
  @spec fetch_transactions(pos_integer, pos_integer, Keyword.t()) :: on_success | on_failure

  def fetch_transactions(page, page_size, opts \\ []) do
    case ExternalApiMock.fetch_transactions(page, page_size, opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
