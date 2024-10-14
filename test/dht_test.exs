defmodule DhtTest do
  use ExUnit.Case
  doctest Dht

  test "greets the world" do
    assert Dht.hello() == :world
  end
end
