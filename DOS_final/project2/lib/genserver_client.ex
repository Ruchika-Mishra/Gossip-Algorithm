defmodule Client do
  use GenServer

  def start_link(x) do
    GenServer.start_link(Server, x)
  end

  def send_message(server) do
    GenServer.cast(server, {:send_rumour})
  end

  def send_message_push_sum(server) do
    GenServer.cast(server, {:send_rumour_push_sum})
  end

  def set_neighbors(server, neighbors) do
    GenServer.cast(server, {:setNeighbors, neighbors})
  end

  def get_count(server) do
    {:ok, count} = GenServer.call(server, {:getCount, "count"})
    count
  end

  def get_rumour(server) do
    {:ok, rumour} = GenServer.call(server, {:getRumour, "rumour"})
    rumour
  end

  def has_neighbors(server) do
    {:ok, neighbors} = GenServer.call(server, {:getNeighbors})
    length(neighbors) > 0
  end

  def get_neighbors(server) do
    GenServer.call(server, {:getNeighbors})
  end

  def get_diff(server) do
    GenServer.call(server, {:getDiff})
  end
end
