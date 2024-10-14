defmodule Dht.Node do
  use Agent

  @moduledoc """
  This module implements the node.
  """

  def start_link(state, opts \\ []) do
    Agent.start_link(fn -> state end, opts)
  end

  def get(pid, key) do
    Agent.get(pid, fn state -> Map.fetch(state, key) end)
  end

  def update(pid, key, value) do
    Agent.update(pid, fn state -> Map.put(state, key, value) end)
  end

  def delete(pid, key) do
    Agent.get_and_update(pid, fn state -> Map.pop(state, key) end)
  end
end
