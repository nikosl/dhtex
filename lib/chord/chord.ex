defmodule Dht.Chord do
  alias Dht.Chord
  alias Dht.Chord.FingerTable
  alias Dht.Chord.Node

  @moduledoc """
  This module implements the Chord protocol.
  """

  @type id_t() :: iodata()

  defstruct predecessor: nil, finger_table: nil, successor: nil, node: nil

  @hash_size 160

  def create(id, node, m \\ @hash_size) do
    finger_table = FingerTable.init(id, m)
    %Chord{predecessor: nil, finger_table: finger_table, successor: node, node: node}
  end

  def find_successor(%Chord{successor: s} = t, id) when is_nil(s) do
    {:preceding, closest_preceding_node(t, id)}
  end

  def find_successor(%Chord{successor: s, node: n} = t, id) do
    if in_range_exl?(id, n.id, s.id) or id == s.id do
      {:successor, s}
    else
      n0 = closest_preceding_node(t, id)
      {:preceding, n0}
    end
  end

  def notify(%Chord{predecessor: p} = t, n) when is_nil(p), do: %Chord{t | predecessor: n}

  def notify(%Chord{node: n, predecessor: p} = t, ntf) do
    if in_range_exl?(ntf.id, p.id, n.id) do
      %Chord{t | predecessor: ntf}
    else
      t
    end
  end

  def stabilize(%Chord{successor: s, node: n} = t, p) do
    require Logger

    Logger.info("Stabilizing node: #{inspect(n)} (#{p.id}, #{n.id}, #{s.id} )")

    if in_range_exl?(p.id, n.id, s.id) do
      %Chord{t | successor: p}
    else
      t
    end
  end

  def closest_preceding_node(%Chord{finger_table: finger, node: node}, id) do
    n = node.id

    if n < id do
      finger.table
      |> Enum.reverse()
      |> Enum.find({n, node}, fn {i, p} -> in_range_exl?(i, n, id) and p != nil end)
      |> elem(1)
    else
      node
    end
  end

  def predecessor(%Chord{predecessor: p}), do: p

  def successor(%Chord{successor: s}), do: s

  def finger_table(%Chord{finger_table: f}), do: f

  def node(%Chord{node: n}), do: n

  def in_range_exl?(i, s, e) do
    cond do
      s == e ->
        false

      s < e ->
        i > s and i < e

      s > e ->
        i > s or i < e
    end
  end

  @spec hash(iodata()) :: integer()
  def hash(id) do
    :crypto.hash(:sha, id) |> :binary.decode_unsigned()
  end

  def hash_size do
    @hash_size
  end

  defmodule Node do
    @moduledoc """
    This module implements the node.
    """

    @enforce_keys [:id, :addr]
    defstruct id: 0, name: "", addr: nil

    def new(id, name, addr) do
      %Node{id: id, name: name, addr: addr}
    end

    def id(%Node{id: id}), do: id
    def name(%Node{name: name}), do: name
    def addr(%Node{addr: addr}), do: addr
  end

  defmodule FingerTable do
    alias Dht.Chord

    @moduledoc """
    This module implements the finger table.
    """

    @type id_t() :: iodata()

    @type node_info_t() :: term()

    @type node_t() :: {id_t(), node_info_t() | nil}

    @type t() :: %FingerTable{table: [node_t()], m: integer()}

    @enforce_keys [:table, :m]
    defstruct table: [], m: 0, id: 0, next: 0

    def init(id, m) do
      f = for i <- 0..(m - 1), do: {hash_node(id, i, m), nil}
      %FingerTable{table: f, m: m, id: id, next: 0}
    end

    def next(%FingerTable{id: id, next: i, m: m}) do
      hash_node(id, i, m)
    end

    def fix_fingers(%FingerTable{next: next, m: m, table: t} = f, s) do
      t =
        t
        |> Enum.with_index()
        |> Enum.map(fn {{id, n}, i} -> if i == next, do: {id, s}, else: {id, n} end)

      next = (next + 1) |> rem(m)

      %FingerTable{f | next: next, table: t}
    end

    @spec hash_node(id_t(), integer(), integer()) :: integer()
    def hash_node(n, i, m) do
      s = Chord.hash(n) + idx_growth(i)
      rem(s, id_space(m))
    end

    @spec id_space(integer()) :: integer()
    def id_space(m) do
      :math.pow(2, m) |> trunc()
    end

    @spec idx_growth(integer()) :: integer()
    def idx_growth(i) do
      :math.pow(2, i) |> trunc()
    end
  end

  defimpl Enumerable, for: FingerTable do
    def count(%FingerTable{table: t}), do: {:ok, Enum.count(t)}
    def member?(%FingerTable{table: t}, element), do: {:ok, Enum.member?(t, element)}
    def reduce(%FingerTable{table: t}, acc, fun), do: Enum.reduce(t, acc, fun)
    def slice(%FingerTable{}), do: {:error, __MODULE__}
  end
end
