defmodule TransactionApi.Mock.ExternalApi.ExternalApiMock do
  @moduledoc """
  A mock external API GenServer for simulating HTTP-based transaction fetching.

  ## Features

  - Initializes with transactions for the last N days (configurable).
  - Adds new transactions for each new day (configurable interval).
  - Supports paginated fetches and random error simulation.
  - Lets you fetch all transactions or filter by date.
  - Returns responses as `%HTTPoison.Response{}` or `%HTTPoison.Error{}` structs, simulating HTTPoison.
  """

  use GenServer

  @type transaction :: %{
          account_number: String.t(),
          amount: String.t(),
          currency: String.t(),
          created_at: String.t(),
          status: String.t()
        }
  @type paginated_response :: %{
          data: [transaction()],
          page: pos_integer(),
          page_size: pos_integer(),
          total: non_neg_integer(),
          total_pages: pos_integer()
        }
  @type state :: %{current_day: Date.t()}
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

  def init(_opts) do
    :ok = setup_mnesia()
    today = Date.utc_today()
    :ok = load_or_generate_transactions(today)
    Process.send_after(self(), :advance_day, advance_interval_ms())
    {:ok, %{current_day: today}}
  end

  @spec handle_call({:fetch, pos_integer, pos_integer, Keyword.t()}, {pid(), term}, state) ::
          {:reply, %HTTPoison.Response{} | %HTTPoison.Error{}, state}
  def handle_call({:fetch, page, page_size, opts}, _from, state) do
    case maybe_simulate_error() do
      {:error, reason} ->
        {:reply, %HTTPoison.Error{id: nil, reason: reason}, state}

      :ok ->
        date_filter = Keyword.get(opts, :date)
        transactions = fetch_all_transactions_from_mnesia()
        filtered = filter_transactions(transactions, date_filter)
        {paginated, total, total_pages} = paginate(filtered, page, page_size)

        response = %{
          data: paginated,
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
           request_url: "*[*http://mock.api/transactions*](http://mock.api/transactions)*"
         }, state}
    end
  end

  @spec handle_info(:advance_day, state) :: {:noreply, state}

  def handle_info(:advance_day, state) do
    new_day = Date.add(state.current_day, 1)
    new_transactions = generate_transactions_for_day(new_day)

    :mnesia.transaction(fn ->
      Enum.each(new_transactions, fn {transaction_id, tx} ->
        :mnesia.write({:mock_transactions, transaction_id, tx})
      end)
    end)

    Process.send_after(self(), :advance_day, advance_interval_ms())
    {:noreply, %{state | current_day: new_day}}
  end

  # Private

  defp maybe_simulate_error do
    prob = error_probability()
    roll = :rand.uniform()

    cond do
      roll < prob / 3 -> {:error, :timeout}
      roll < 2 * prob / 3 -> {:error, :rate_limit}
      roll < prob -> {:error, :api_failure}
      true -> :ok
    end
  end

  defp fetch_all_transactions_from_mnesia do
    :mnesia.transaction(fn ->
      :mnesia.match_object({:mock_transactions, :_, :_})
    end)
    |> case do
      {:atomic, results} ->
        Enum.map(results, fn {:mock_transactions, _id, tx} -> tx end)

      _ ->
        []
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
    |> Enum.reduce([], fn _i, acc -> maybe_duplicate_transaction(acc, day, prob) end)
    |> Enum.reverse()
  end

  defp maybe_duplicate_transaction(acc, day, prob) do
    if :rand.uniform() < prob and acc != [] do
      tx = Enum.random(acc)
      [duplicate_transaction(tx, day) | acc]
    else
      transaction_id = "tx-#{System.system_time(:microsecond)}"

      new_tx = %{
        account_number: "ACC#{1000 + :rand.uniform(20)}",
        amount: Float.round(:rand.uniform() * 1000, 2) |> to_string(),
        currency: "USD",
        created_at: Date.to_iso8601(day),
        status: "finished"
      }

      [{transaction_id, new_tx} | acc]
    end
  end

  defp duplicate_transaction({_, tx}, day) do
    transaction_id = "tx-#{System.system_time(:microsecond)}"
    {transaction_id, %{tx | created_at: Date.to_iso8601(day)}}
  end

  defp setup_mnesia do
    IO.inspect(node(), label: "Node name at runtime")

    # Read configured dir (charlist or binary) and normalize to string for FS checks
    dir_cfg = Application.get_env(:mnesia, :dir) || ~c"/mnesia"
    IO.inspect(dir_cfg, label: "Mnesia dir at runtime")
    dir_str = to_string(dir_cfg)

    # 1) Ensure directory exists and create schema if schema.DAT is missing
    File.mkdir_p!(dir_str)
    schema_file = Path.join(dir_str, "schema.DAT")

    if not File.exists?(schema_file) do
      case :mnesia.create_schema([node()]) do
        :ok -> :ok
        # Accept "already_exists" variants and proceed
        {:error, {:already_exists, _}} -> :ok
        {:error, {_n, {:already_exists, _}}} -> :ok
        other -> raise "create_schema failed: #{inspect(other)}"
      end
    end

    # 2) Start and wait for the schema table to be up
    :ok = :mnesia.start()

    case :mnesia.wait_for_tables([:schema], 10_000) do
      :ok -> :ok
      {:timeout, _} -> raise "Mnesia schema did not come up in time"
    end

    # 3) Ensure the schema itself is DISK on THIS node
    schema_disks =
      try do
        :mnesia.table_info(:schema, :disc_copies)
      rescue
        _ -> []
      end

    schema_rams =
      try do
        :mnesia.table_info(:schema, :ram_copies)
      rescue
        _ -> []
      end

    cond do
      node() in schema_disks ->
        :ok

      node() in schema_rams ->
        case :mnesia.change_table_copy_type(:schema, node(), :disc_copies) do
          {:atomic, :ok} -> :ok
          other -> raise "change_table_copy_type(schema -> disc) failed: #{inspect(other)}"
        end

      true ->
        case :mnesia.add_table_copy(:schema, node(), :disc_copies) do
          {:atomic, :ok} -> :ok
          {:aborted, {:already_exists, :schema, _}} -> :ok
          other -> raise "add_table_copy(schema, disc) failed: #{inspect(other)}"
        end
    end

    # 4) Create or reuse your table with DISK persistence
    create_opts = [
      attributes: [:id, :transaction],
      type: :set,
      disc_copies: [node()]
    ]

    case :mnesia.create_table(:mock_transactions, create_opts) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, :mock_transactions}} ->
        :ok

      {:aborted, {:already_exists, :mock_transactions, _}} ->
        :ok

      other ->
        raise "Mnesia table creation failed: #{inspect(other)}"
    end

    # 5) Ensure THIS node actually has a DISK copy of the table (covers reuse path)
    table_disks =
      try do
        :mnesia.table_info(:mock_transactions, :disc_copies)
      rescue
        _ -> []
      end

    unless node() in table_disks do
      case :mnesia.add_table_copy(:mock_transactions, node(), :disc_copies) do
        {:atomic, :ok} -> :ok
        {:aborted, {:already_exists, :mock_transactions, _}} -> :ok
        other -> raise "add_table_copy(:mock_transactions, disc) failed: #{inspect(other)}"
      end
    end

    # 6) Wait until the table is fully available
    case :mnesia.wait_for_tables([:mock_transactions], 10_000) do
      :ok -> :ok
      {:timeout, _} -> raise "mock_transactions did not come up in time"
    end

    :ok
  end

  defp load_or_generate_transactions(today) do
    existing =
      :mnesia.transaction(fn ->
        :mnesia.match_object({:mock_transactions, :_, :_})
      end)

    case existing do
      {:atomic, []} ->
        generated =
          Enum.flat_map(0..days_back(), fn offset ->
            day = Date.add(today, -offset)
            generate_transactions_for_day(day)
          end)

        :mnesia.transaction(fn ->
          Enum.each(generated, fn {transaction_id, tx} ->
            :mnesia.write({:mock_transactions, transaction_id, tx})
          end)
        end)

        :ok

      {:atomic, _rows} ->
        :ok

      other ->
        raise "mnesia read failed: #{inspect(other)}"
    end
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
