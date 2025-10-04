defmodule TransactionApi.Mock.ExternalApi.ExternalApiMock do
  @moduledoc """
  Simple mock external API GenServer.

  - Initializes with transactions for the last N days (configurable).
  - Adds new transactions for each new day (configurable interval).
  - Supports paginated fetches and random error simulation.
  - Lets you fetch all transactions or filter by date.

  """

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def fetch_transactions(page \\ 1, page_size \\ 100, opts \\ []) do
    case GenServer.call(__MODULE__, {:fetch, page, page_size, opts}) do
      {:ok, response_json} ->
        Jason.decode!(response_json)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def init(_init_arg) do
    today = Date.utc_today()
    # Generate transactions for each day from (today - days_back) to today
    all_transactions =
      Enum.flat_map(0..days_back(), fn offset ->
        day = Date.add(today, -offset)
        generate_transactions_for_day(day)
      end)

    Process.send_after(self(), :advance_day, advance_interval_ms())
    {:ok, %{current_day: today, all_transactions: all_transactions}}
  end

  def handle_call({:fetch, page, page_size, opts}, _from, state) do
    case :rand.uniform(100) do
      1 ->
        {:reply, {:error, :timeout}, state}

      2 ->
        {:reply, {:error, :rate_limit}, state}

      3 ->
        {:reply, {:error, :api_failure}, state}

      _ ->
        date_filter = Keyword.get(opts, :date)

        transactions =
          case date_filter do
            nil -> state.all_transactions
            date -> Enum.filter(state.all_transactions, fn tx -> tx.created_at == date end)
          end

        start_idx = (page - 1) * page_size
        paginated = Enum.slice(transactions, start_idx, page_size)
        total = length(transactions)
        total_pages = if total == 0, do: 1, else: div(total + page_size - 1, page_size)

        response = %{
          data: paginated,
          page: page,
          page_size: page_size,
          total: total,
          total_pages: total_pages
        }

        {:reply, {:ok, Jason.encode!(response)}, state}
    end
  end

  def handle_info(:advance_day, state) do
    new_day = Date.add(state.current_day, 1)
    new_transactions = generate_transactions_for_day(new_day)
    all_transactions = state.all_transactions ++ new_transactions

    Process.send_after(self(), :advance_day, advance_interval_ms())
    {:noreply, %{state | current_day: new_day, all_transactions: all_transactions}}
  end

  # Private

  defp generate_transactions_for_day(day) do
    prob = duplicate_probability()

    Enum.reduce(1..transactions_added_per_minute(), [], fn _i, acc ->
      if :rand.uniform() < prob and acc != [] do
        tx = Enum.random(acc)
        [%{tx | created_at: Date.to_iso8601(day)} | acc]
      else
        new_tx = %{
          account_number: "ACC#{1000 + :rand.uniform(20)}",
          amount: Float.round(:rand.uniform() * 1000, 2) |> to_string(),
          currency: "USD",
          created_at: Date.to_iso8601(day),
          status: "finished"
        }

        [new_tx | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp days_back do
    Application.get_env(:reconciliation_api, :mock)
    |> Keyword.get(:days_back, 30)
  end

  defp advance_interval_ms do
    Application.get_env(:reconciliation_api, :mock)
    |> Keyword.get(:advance_interval_ms, 60_000)
  end

  defp transactions_added_per_minute do
    Application.get_env(:reconciliation_api, :mock)
    |> Keyword.get(:transactions_added_per_minute, 100)
  end

  defp duplicate_probability do
    Application.get_env(:reconciliation_api, :mock)
    |> Keyword.get(:duplicate_probability, 0.1)
  end
end
