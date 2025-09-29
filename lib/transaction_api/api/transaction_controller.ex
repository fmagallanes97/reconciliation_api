defmodule TransactionApi.Api.TransactionController do
  use TransactionApiWeb, :controller

  alias TransactionApi.Repo
  alias TransactionApi.Schema.Transaction

  import Ecto.Query

  @doc """
  Returns all transactions ordered by created_at date (ascending).
  """
  def list_transactions(conn, _params) do
    transactions =
      from(t in Transaction, order_by: [asc: t.created_at], limit: 20)
      |> Repo.all()

    render(conn, "index.json", transactions: transactions)
  end
end
