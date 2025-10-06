defmodule ReconciliationApi.Api do
  @moduledoc """
  HTTP-client-agnostic interface for fetching transactions from an external service.
  By default, uses a mock implementation that simulates HTTP responses, but can be swapped for a real HTTP client.
  """

  alias TransactionApi.Mock.ExternalApi.ExternalApiMock

  @type transaction :: ExternalApiMock.transaction()
  @type transactions :: [transaction()]
  @type paginated_response :: ExternalApiMock.paginated_response()
  @type error :: ExternalApiMock.error()
  @type on_success :: {:ok, paginated_response()}
  @type on_failure :: {:error, error()}

  @doc """
  Fetches transactions from the external API (mock by default).
  Supports pagination and returns either a paginated response or an error.
  """
  @spec fetch_transactions(pos_integer, pos_integer, Keyword.t()) :: on_success | on_failure

  def fetch_transactions(page, page_size, opts \\ []) do
    case ExternalApiMock.fetch_transactions(page, page_size, opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body, keys: :atoms)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
