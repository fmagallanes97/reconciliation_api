defmodule ReconciliationApi.Util.Retry do
  @moduledoc """
  Simple retry utility with exponential backoff and jitter.
  """

  require Logger

  @type result :: {:ok, any()} | {:error, any()}
  @type retry_fun :: (-> result)
  @type retryable_fun :: (any() -> boolean())

  @doc """
  Retries the given function up to `max_attempts` times with exponential backoff and jitter.
  Returns `{:ok, result}` on success, or `{:error, reason}` if all attempts fail.
  """
  @spec retry(retry_fun, pos_integer()) :: result

  def retry(fun, max_attempts)
      when is_function(fun, 0) and is_integer(max_attempts) and max_attempts > 0 do
    retry(fun, max_attempts, fn _ -> true end)
  end

  @doc """
  Retries the given function up to `max_attempts` times, using the provided `retryable?/1` function to determine if an error is retryable.
  """
  @spec retry(retry_fun, pos_integer(), retryable_fun) :: result

  def retry(fun, max_attempts, retryable?)
      when is_function(fun, 0) and is_integer(max_attempts) and max_attempts > 0 and
             is_function(retryable?, 1) do
    do_retry(fun, max_attempts, 0, retryable?)
  end

  @doc """
  Returns true if the error is considered retryable.
  By default, only `:timeout` and `:rate_limit` are considered retryable.
  """
  @spec retryable_error?(atom()) :: boolean()

  def retryable_error?(:timeout), do: true
  def retryable_error?(:rate_limit), do: true
  def retryable_error?(_), do: false

  # Private

  defp do_retry(_fun, 0, _attempt, _retryable?), do: {:error, :max_attempts_reached}

  defp do_retry(fun, attempts_left, attempt, retryable?) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        if attempts_left > 1 and retryable?.(reason) do
          delay = backoff_with_jitter(attempt)

          Logger.warning(
            "Retry #{attempt + 1}/#{attempt + attempts_left}: #{inspect(reason)}, sleeping #{delay}ms"
          )

          Process.sleep(delay)
          do_retry(fun, attempts_left - 1, attempt + 1, retryable?)
        else
          Logger.error("Max retries reached (#{attempt + 1}): #{inspect(reason)}")
          {:error, reason}
        end
    end
  end

  defp backoff_with_jitter(attempts) do
    base_delay = :math.pow(2, attempts) * 100
    jitter = :rand.uniform(100)
    round(base_delay + jitter)
  end
end
