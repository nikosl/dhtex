defmodule Dht.Chord.Srv do
  use GenServer
  require Logger

  alias Dht.Chord
  alias Dht.Chord.FingerTable

  @moduledoc """
  This module implements the Chord server.
  """
  @stabilize_interval 5_000
  @fix_fingers_interval 10_000

  # heartbeat pred
  #   // called periodically. checks whether predecessor has failed.
  # n.check_predecessor()
  #   if predecessor has failed then
  #       predecessor := nil

  def start_link(opts \\ []) do
    id = UUID.uuid4(:hex)

    GenServer.start_link(__MODULE__, %{name: id}, opts)
  end

  def predecessor(n) do
    GenServer.call(n, :predecessor)
  end

  def successor(n) do
    GenServer.call(n, :successor)
  end

  def snapshot(n) do
    GenServer.call(n, :snapshot)
  end

  def find_successor(n, id) do
    GenServer.call(n, {:find_successor, id})
  end

  def join(n, node) do
    GenServer.call(n, {:join, node})
  end

  def notify(n, node) do
    GenServer.cast(n, {:notify, node})
  end

  def stabilize(n) do
    GenServer.cast(n, :stabilize)
  end

  def fix_fingers(n) do
    GenServer.cast(n, :fix_fingers)
  end

  def stop(n) do
    Logger.info("Stopping Chord node: #{inspect(n)}")

    GenServer.stop(n, :shutdown)
  end

  def node(n) do
    GenServer.call(n, :node)
  end

  def lring(n) do
    GenServer.cast(n, :inspect)
  end

  @impl true
  def init(cnf) do
    %{name: name} = cnf
    id = Chord.hash(name)

    Logger.info("Starting Chord server with name: #{name} id: #{id}")

    schedule_fix_fingers()
    schedule_stabilize()

    # {:ok, pid} = Dht.Node.start_link(%{})
    node = Chord.Node.new(id, name, self())
    chord = Chord.create(name, node)

    Registry.register(Dht.Registry, "chord", id)

    {:ok, chord}
  end

  @impl true
  def handle_call(:predecessor, _, %Chord{predecessor: p} = st) do
    p = if p, do: {:ok, p}, else: {:error, :predecessor_not_known}

    {:reply, p, st}
  end

  @impl true
  def handle_call({:find_successor, id}, _, %Chord{} = ring) do
    n = find_successor_op(ring, id)

    Logger.info("Find #{id} successor: #{inspect(n)}")

    {:reply, n, ring}
  end

  @impl true
  def handle_call({:join, node}, _, ring) do
    if ring.node.id != node.id do
      case GenServer.call(node.addr, {:find_successor, node.id}) do
        {:ok, s} ->
          ring =
            %Chord{ring | successor: s}

          Logger.info("Joining node: #{inspect(s)}")

          {:reply, {:ok, :joined}, ring}

        {:error, e} ->
          Logger.error("Joining node: #{inspect(node)} failed: #{e}")

          {:reply, {:error, e}, ring}

        _ ->
          Logger.error("Joining node: #{inspect(node)} failed: unknown error")

          {:reply, {:error, :unknown}, ring}
      end
    else
      Logger.info("Joining node: #{inspect(node)} failed: same node")

      {:reply, {:error, :same_id}, ring}
    end
  end

  @impl true
  def handle_call(:node, _, ring) do
    n = ring |> Chord.node()

    {:reply, n, ring}
  end

  @impl true
  def handle_call(:successor, _, %Chord{successor: s} = ring) do
    {:reply, s, ring}
  end

  @impl true
  def handle_call(:snapshot, _, ring) do
    {:reply, ring, ring}
  end

  @impl true
  def handle_call({:get, key}, _, ring) do
    {:reply, {:error, key}, ring}
  end

  @impl true
  def handle_call({:put, key, value}, _, ring) do
    {:reply, {:error, {key, value}}, ring}
  end

  @impl true
  def handle_cast({:notify, node}, ring) do
    op = ring |> Chord.predecessor()

    ring = Chord.notify(ring, node)

    np = ring |> Chord.predecessor()

    transt(op, np, "predecessor")
    # Logger.info("Notify from: #{inspect(node)}")

    {:noreply, ring}
  end

  @impl true
  def handle_cast(:stabilize, %Chord{successor: s, node: n} = ring) do
    os = ring |> Chord.successor()
    op = ring |> Chord.predecessor()

    ring = if s.id != n.id, do: stabilize_op(ring, n, s), else: ring

    schedule_stabilize()

    ns = ring |> Chord.successor()
    np = ring |> Chord.predecessor()

    transt(os, ns, "successor")
    transt(op, np, "predecessor")

    {:noreply, ring}
  end

  @impl true
  def handle_cast(:fix_fingers, ring) do
    # Logger.info("Fix fingers...")

    %Chord{finger_table: t} = ring
    n = FingerTable.next(t)

    ring =
      case find_successor_op(ring, n) do
        {:ok, s} ->
          if ring.node.id != s.id do
            Logger.info("Fixing finger: #{n} successor: #{inspect(s)}")
          end

          t = FingerTable.fix_fingers(t, s)

          %Chord{ring | finger_table: t}

        _ ->
          Logger.error("Failed to fix finger: #{n}")

          ring
      end

    schedule_fix_fingers()

    {:noreply, ring}
  end

  @impl true
  def handle_cast(:inspect, ring) do
    Logger.info("ring: #{inspect(ring)}")

    {:noreply, ring}
  end

  @impl true
  def handle_info(:fix_fingers, ring) do
    self() |> fix_fingers()

    {:noreply, ring}
  end

  @impl true
  def handle_info(:stabilize, ring) do
    self() |> stabilize()

    {:noreply, ring}
  end

  @impl true
  def handle_info(msg, ring) do
    Logger.error("Unknown message: #{inspect(msg)}")

    {:noreply, ring}
  end

  def find_successor_op(%Chord{node: node} = ring, id) do
    case Chord.find_successor(ring, id) do
      {:successor, s} ->
        # Logger.info("Found table #{id} successor: #{inspect(s)}")

        {:ok, s}

      {:preceding, p} ->
        # Logger.info("Preceding #{id} successor: #{inspect(p)}")

        if p.id != node.id do
          Logger.info("Forwarding #{id} to: #{inspect(p)}")

          GenServer.call(p.addr, {:find_successor, id})
        else
          {:ok, p}
        end
    end
  end

  defp stabilize_op(ring, n, s) do
    notify(s.addr, n)

    case predecessor(s.addr) do
      {:ok, p} ->
        # Logger.info("Stabilize predecessor: #{inspect(p)}")

        Chord.stabilize(ring, p)

      _ ->
        # Logger.error("Failed to stabilize: predecessor not found")

        ring
    end
  end

  defp schedule_stabilize(t \\ @stabilize_interval) do
    Process.send_after(self(), :stabilize, t)
  end

  defp schedule_fix_fingers(t \\ @fix_fingers_interval) do
    Process.send_after(self(), :fix_fingers, t)
  end

  def opt_map(o, f) do
    case o do
      nil -> nil
      _ -> f.(o)
    end
  end

  defp transt(o, n, w) do
    case {o, n} do
      {nil, n} when not is_nil(n) ->
        Logger.info("Transition #{w} (#{inspect(self())}): nil -> #{inspect(n)}")

      {o, nil} when not is_nil(o) ->
        Logger.info("Transition #{w} (#{inspect(self())}): #{inspect(o)} -> nil")

      {nil, nil} ->
        :ok

      {o, n} when o.id != n.id ->
        Logger.info("Transition #{w} (#{inspect(self())}): #{inspect(o)} -> #{inspect(n)}")

      _ ->
        :ok
    end
  end
end
