defmodule TransactionApi.Mock.ExternalApi.ExternalApiMock do
  @moduledoc """
  A mock external API GenServer for simulating HTTP-based transaction fetching.

  ## Features

    - Initializes with transactions for the last N days (configurable).
    - Adds new transactions for each new day (configurable interval).
    - Supports paginated fetches and random error simulation.
    - Lets you fetch all transactions or filter by date.
    - Returns responses as `%HTTPoison.Response{}` or `%HTTPoison.Error{}` structs, simulating HTTPoison.

  ## Example API Response (decoded)

  %{
    "data" => [
      %{
        "account_number" => "1",
        "amount" => "1",
        "currency" => "USD",
        "created_at" => "2024-06-10",
        "status" => "finished"
      }
    ],
    "page" => 1,
    "page_size" => 100,
    "total" => 123,
    "total_pages" => 2
  }
  """

  use GenServer

  @type transaction :: %{
          account_number: String.t(),
          amount: String.t(),
          currency: String.t(),
          created_at: String.t(),
          status: String.t()
        }
  @type state :: %{
          current_day: Date.t(),
          all_transactions: [transaction]
        }
  @type response :: %{String.t() => any()}
  @type error :: :timeout | :rate_limit | :api_failure | atom

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec fetch_transactions(pos_integer, pos_integer, Keyword.t()) ::
          {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}

  def fetch_transactions(page \\ 1, page_size \\ 100, opts \\ []) do
    case GenServer.call(__MODULE__, {:fetch, page, page_size, opts}) do
      %HTTPoison.Response{} = res -> {:ok, res}
      %HTTPoison.Error{} = reason -> {:error, reason}
    end
  end

  # Genserver callbacks

  @spec init(Keyword.t()) :: {:ok, state}

  def init(_init_arg) do
    today = Date.utc_today()

    all_transactions =
      Enum.flat_map(0..days_back(), fn offset ->
        day = Date.add(today, -offset)
        generate_transactions_for_day(day)
      end)

    Process.send_after(self(), :advance_day, advance_interval_ms())
    {:ok, %{current_day: today, all_transactions: all_transactions}}
  end

  @spec handle_call({:fetch, pos_integer, pos_integer, Keyword.t()}, {pid(), term}, state) ::
          {:reply, %HTTPoison.Response{} | %HTTPoison.Error{}, state}

  def handle_call({:fetch, page, page_size, opts}, _from, state) do
    case maybe_simulate_error() do
      {:error, reason} ->
        {:reply, %HTTPoison.Error{id: nil, reason: reason}, state}

      :ok ->
        date_filter = Keyword.get(opts, :date)
        transactions = filter_transactions(state.all_transactions, date_filter)
        {paginated, total, total_pages} = paginate(transactions, page, page_size)

        # transaction_id is not public for this challenge
        public_paginated =
          Enum.map(paginated, fn tx ->
            Map.drop(tx, [:transaction_id])
          end)

        response = %{
          data: public_paginated,
          page: page,
          page_size: page_size,
          total: total,
          total_pages: total_pages
        }

        {:reply,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(response),
           headers: [{"content-type", "application/json"}],
           request_url: "http://mock.api/transactions"
         }, state}
    end
  end

  @spec handle_info(:advance_day, state) :: {:noreply, state}

  def handle_info(:advance_day, state) do
    new_day = Date.add(state.current_day, 1)
    new_transactions = generate_transactions_for_day(new_day)
    all_transactions = state.all_transactions ++ new_transactions

    Process.send_after(self(), :advance_day, advance_interval_ms())
    {:noreply, %{state | current_day: new_day, all_transactions: all_transactions}}
  end

  # Private

  defp maybe_simulate_error do
    prob = error_probability()
    roll = :rand.uniform()

    case roll do
      r when r < prob / 3 -> {:error, :timeout}
      r when r < 2 * prob / 3 -> {:error, :rate_limit}
      r when r < prob -> {:error, :api_failure}
      _ -> :ok
    end
  end

  defp filter_transactions(transactions, nil), do: transactions

  defp filter_transactions(transactions, date),
    do: Enum.filter(transactions, &(&1.created_at == date))

  defp paginate(transactions, page, page_size) do
    start_idx = (page - 1) * page_size
    paginated = Enum.slice(transactions, start_idx, page_size)
    total = length(transactions)
    total_pages = if total == 0, do: 1, else: div(total + page_size - 1, page_size)
    {paginated, total, total_pages}
  end

  defp generate_transactions_for_day(day) do
    prob = duplicate_probability()

    1..transactions_added_per_minute()
    |> Enum.reduce([], fn _, acc -> maybe_duplicate_transaction(acc, day, prob) end)
    |> Enum.reverse()
  end

  defp maybe_duplicate_transaction(acc, day, prob) do
    if :rand.uniform() < prob and acc != [] do
      tx = Enum.random(acc)
      [duplicate_transaction(tx, day) | acc]
    else
      new_tx = %{
        transaction_id: "tx-#{System.system_time(:microsecond)}",
        account_number: "ACC#{1000 + :rand.uniform(20)}",
        amount: Float.round(:rand.uniform() * 1000, 2) |> to_string(),
        currency: "USD",
        created_at: Date.to_iso8601(day),
        status: "finished"
      }

      [new_tx | acc]
    end
  end

  defp duplicate_transaction(tx, day) do
    %{
      tx
      | created_at: Date.to_iso8601(day),
        transaction_id: "tx-#{System.system_time(:microsecond)}"
    }
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

  defp error_probability do
    Application.get_env(:reconciliation_api, :mock)
    |> Keyword.get(:error_probability, 0.05)
  end
end
