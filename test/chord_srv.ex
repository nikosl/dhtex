defmodule ChordSrv do
  use ExUnit.Case
  alias Dht.Chord.Srv

  setup do
    {:ok, pid} = Srv.start_link([])
    {:ok, pid1} = Srv.start_link([])

    {:ok, pa: pid, pb: pid1}
  end

  describe "description_of_tests" do
    test "definition_of_this_test", %{pa: pid, pb: pid1} do
      n0 = Srv.node(pa)
      Srv.join(pb, n0)
    end
  end
end
