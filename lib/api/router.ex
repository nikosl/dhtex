defmodule Dht.Api.Router do
  alias Dht.Api.Controller
  alias Dht.Chord
  alias Dht.Chord.Srv

  use Plug.Router

  plug(Plug.Static,
    at: "/assets",
    from: :dhtex,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
  )

  plug(:match)
  plug(:dispatch)

  @index_path Path.join(:code.priv_dir(:dhtex), "index.html.eex")

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, page_render())
  end

  get "/update-graph" do
    snap = Controller.snapshots()
    srv = Controller.srv(snap)

    nodes = srv |> Controller.nodes_names() |> Controller.nodes_label()
    fingers = srv |> Controller.finger_edges()
    # |> Enum.concat(fingers)
    edges =
      srv
      |> Controller.edges()
      |> Enum.sort(fn %{from: a}, %{from: b} -> a < b end)
      |> Enum.concat(fingers)

    new_data = %{
      nodes: nodes,
      edges: edges
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(new_data))
  end

  post "/nodes/start" do
    n =
      Registry.lookup(Dht.Registry, "chord")
      |> Enum.map(fn {pid, _} -> pid end)
      |> Enum.take_random(1)
      |> Enum.map(&Srv.node/1)

    {:ok, pid} = Srv.start_link()
    n |> Enum.map(fn n -> Srv.join(pid, n) end)

    id =
      Srv.node(pid)
      |> Chord.Node.name()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{id: id}))
  end

  get "/data" do
    nodes = [%{id: 1, label: "Node 1"}, %{id: 2, label: "Node 2"}]
    edges = [%{from: 1, to: 2}]

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{nodes: nodes, edges: edges}))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp index_template, do: @index_path

  defp page_render do
    index_template() |> EEx.eval_file()
  end
end
