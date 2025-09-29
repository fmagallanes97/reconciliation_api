defmodule TransactionApiTest do
  use ExUnit.Case
  doctest TransactionApi

  test "greets the world" do
    assert TransactionApi.hello() == :world
  end
end
