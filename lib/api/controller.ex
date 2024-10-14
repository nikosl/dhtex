defmodule Dht.Api.Controller do
  alias Dht.Chord
  alias Dht.Chord.Srv

  @moduledoc """
  This module implements the API controller.
  """

  def snapshots do
    n = Registry.lookup(Dht.Registry, "chord")
    n |> Enum.map(fn {pid, _} -> pid end) |> Enum.map(fn n -> Srv.snapshot(n) end)
  end

  def node_ids(srv) do
    srv |> Enum.map(fn {id, _} -> id end)
  end

  def srv(snap) do
    snap |> Enum.map(fn %Chord{node: n} = state -> {n.id, state} end) |> Enum.into(%{})
  end

  def node(srv, id) do
    %Chord{node: n} = Map.get(srv, id)
    n
  end

  def finger_tables(srv) do
    srv
    |> Enum.map(fn {id, r} ->
      f = r |> Chord.finger_table()

      {id, f.table}
    end)
  end

  def finger(srv, id) do
    f =
      srv
      |> Map.get(id)
      |> Chord.finger_table()

    f.table
  end

  def node_edges(srv, id) do
    %{id: id, predecessor: predecessor(srv, id), successor: successor(srv, id)}
  end

  def nodes_names(srv) do
    for {id, s} <- srv, into: %{} do
      {id, s |> Chord.node() |> Chord.Node.name()}
    end
  end

  def nodes_label(nid) do
    nid |> Enum.map(fn {i, n} -> %{id: i, label: "#{n |> String.slice(0..4)}"} end)
  end

  def edges(srv) do
    srv |> edges_suc() |> Enum.concat(srv |> edges_pred())
  end

  def edges_suc(srv) do
    srv
    |> Enum.map(fn {id, r} ->
      s = r |> Chord.successor()

      if s do
        %{from: id, to: s |> Chord.Node.id()}
      else
        %{}
      end
    end)
    |> Enum.reject(fn m -> map_size(m) == 0 end)
  end

  def edges_pred(srv) do
    srv
    |> Enum.map(fn {id, r} ->
      p = r |> Chord.predecessor()

      if p do
        %{from: p |> Chord.Node.id(), to: id}
      else
        %{}
      end
    end)
    |> Enum.reject(fn m -> map_size(m) == 0 end)
  end

  def finger_edges(srv) do
    ring_edges = fn {id, t} ->
      t
      |> Enum.map(fn {_, n} -> {id, n} end)
      |> Enum.reject(fn {id, n} -> n == nil or n.id == id end)
    end

    f_to_edges = fn {from, to} -> %{from: from, to: to.id, color: "#00CCBF"} end

    srv
    |> finger_tables()
    |> Enum.map(ring_edges)
    |> Enum.flat_map(fn f ->
      f
      |> Enum.map(f_to_edges)
    end)
  end

  def successor(srv, id) do
    s = Map.get(srv, id) |> Chord.successor()

    if s, do: s |> Chord.Node.name(), else: nil
  end

  def predecessor(srv, id) do
    p = Map.get(srv, id) |> Chord.predecessor()

    if p, do: p |> Chord.Node.name(), else: nil
  end
end
