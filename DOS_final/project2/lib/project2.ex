defmodule Project2 do
  # Parse input arguments
  def main(args) do
    {_, input, _} = OptionParser.parse(args, switches: [])

    if length(input) == 3 do
      numNodes = String.to_integer(List.first(input))

      if numNodes > 1 do
        algorithm = List.last(input)
        {topology, _} = List.pop_at(input, 1)

        case algorithm do
          "gossip" ->
            actors = start_actors(numNodes)
            start_algorithm(actors, topology, numNodes, algorithm)

          "push-sum" ->
            actors = start_actors_push_sum(numNodes)
            start_algorithm(actors, topology, numNodes, algorithm)

          _ ->
            IO.puts("Invalid algorithm")
            IO.puts("Enter gossip or push-sum")
            System.halt(0)
        end
      end
    else
      IO.puts("Invalid input. Number of arguments should be 3")
      System.halt(0)
    end
  end

  # Deploy actors for all the nodes
  def start_actors(numNodes) do
    middleNode = trunc(numNodes / 2)

    Enum.map(1..numNodes, fn x ->
      {:ok, actor} =
        cond do
          x == middleNode -> Client.start_link("This is rumour")
          true -> Client.start_link("")
        end

      actor
    end)
  end

  def start_actors_push_sum(numNodes) do
    middleNode = trunc(numNodes / 2)

    Enum.map(
      1..numNodes,
      fn x ->
        {:ok, actor} =
          cond do
            x == middleNode ->
              x = Integer.to_string(x)
              {x, _} = Float.parse(x)
              # Client.start_link returns the pid of the process
              Client.start_link([x] ++ ["This is rumour"])

            true ->
              x = Integer.to_string(x)
              {x, _} = Float.parse(x)
              # Client.start_link returns the pid of the process
              Client.start_link([x] ++ [""])
          end

        actor
      end
    )
  end

  # Build topology of actors based on the input selection
  def start_algorithm(actors, topology, numNodes, algorithm) do
    :ets.new(:count, [:set, :public, :named_table])
    :ets.insert(:count, {"spread", 0})

    topology_map =
      case topology do
        "full" ->
          _topology_map = full_topology(actors)

        "2D" ->
          _topology_map = topology_2d(actors, topology)

        "line" ->
          _topology_map = line_topology(actors, topology)

        "impLine" ->
          _topology_map = line_topology(actors, topology)

        "rand2D" ->
          _topology_map = topology_2d(actors, topology)

        "3D" ->
          _topology_map = topology_3d(actors, topology)

        "imp3D" ->
          _topology_map = topology_3d(actors, topology)

        "torus" ->
          _topology_map = torus_topology(actors)

        _ ->
          IO.puts("Invalid topology")
          IO.puts("Enter topology - full/line/impLine/2D/rand2D/3D/imp3D/torus")
          System.halt(0)
      end

    set_neighbors(topology_map)
    prev = System.monotonic_time(:milliseconds)

    if algorithm == "gossip" do
      gossip(actors, topology_map, numNodes)
    else
      push_sum(actors, topology_map, numNodes)
    end

    IO.puts(
      "Covergence Time: " <> to_string(System.monotonic_time(:milliseconds) - prev) <> " ms"
    )

    System.halt(0)
  end

  # Gossip protocol
  def gossip(actors, topology_map, numNodes) do
    # Send rumor to everu neighbour in the topology
    for {k, _} <- topology_map do
      Client.send_message(k)
    end

    # Check the alive nodes/actors
    actors = check_actors_alive(actors)
    [{_, spread}] = :ets.lookup(:count, "spread")

    # Recursively spread the all the neighbours
    if spread != numNodes && length(actors) > 1 do
      topology_map = Enum.filter(topology_map, fn {k, _} -> Enum.member?(actors, k) end)
      gossip(actors, topology_map, numNodes)
    end
  end

  # Check if the actor is still eligible for gossip
  def check_actors_alive(actors) do
    current_actors =
      Enum.map(actors, fn x ->
        if Process.alive?(x) && Client.get_count(x) < 10 && Client.has_neighbors(x) do
          x
        end
      end)

    List.delete(Enum.uniq(current_actors), nil)
  end

  # Push-Sum Protocol
  # Initialize topology and send rumor to every neighbour
  def push_sum(actors, topology_map, numNodes) do
    for {k, _} <- topology_map do
      Client.send_message_push_sum(k)
    end

    actors = check_actors_alive_push_sum(actors)
    [{_, spread}] = :ets.lookup(:count, "spread")

    # Check if the actor is still eligible for gossip
    if spread != numNodes && length(actors) > 1 do
      topology_map = Enum.filter(topology_map, fn {k, _} -> Enum.member?(actors, k) end)
      push_sum(actors, topology_map, numNodes)
    end
  end

  def check_actors_alive_push_sum(actors) do
    current_actors =
      Enum.map(
        actors,
        fn x ->
          diff = Client.get_diff(x)
          # Check for actors ratio
          if(
            Process.alive?(x) && Client.has_neighbors(x) &&
              (abs(List.first(diff)) > :math.pow(10, -10) ||
                 abs(List.last(diff)) > :math.pow(10, -10))
          ) do
            x
          end
        end
      )

    List.delete(Enum.uniq(current_actors), nil)
  end

  # Build full topology
  def full_topology(actors) do
    Enum.reduce(actors, %{}, fn x, acc ->
      Map.put(acc, x, Enum.filter(actors, fn y -> y != x end))
    end)
  end

  # Build line topology
  def line_topology(actors, topology) do
    # actors_with_index = %{pid1 => 0, pid2 => 1, pid3 => 2}
    actors_with_index =
      Stream.with_index(actors, 0) |> Enum.reduce(%{}, fn {v, k}, acc -> Map.put(acc, k, v) end)

    n = length(actors)

    Enum.reduce(0..(n - 1), %{}, fn x, acc ->
      neighbours =
        cond do
          x == 0 -> [1]
          x == n - 1 -> [n - 2]
          true -> [x - 1, x + 1]
        end

      neighbours =
        case topology do
          "impLine" ->
            neighbours ++ get_random_node(neighbours, x, n - 1)

          _ ->
            neighbours
        end

      neighbor_pids =
        Enum.map(neighbours, fn i ->
          {:ok, n} = Map.fetch(actors_with_index, i)
          n
        end)

      {:ok, actor} = Map.fetch(actors_with_index, x)
      Map.put(acc, actor, neighbor_pids)
    end)
  end

  # create 2D grid topology
  def topology_2d(actors, topology) do
    n = length(actors)
    k = trunc(:math.ceil(:math.sqrt(n)))

    actors_with_index =
      Stream.with_index(actors, 0) |> Enum.reduce(%{}, fn {v, k}, acc -> Map.put(acc, k, v) end)

    Enum.reduce(0..(n - 1), %{}, fn i, acc ->
      neighbours =
        Enum.reduce(1..4, %{}, fn j, acc ->
          if j == 1 && i - k >= 0 do
            Map.put(acc, j, i - k)
          else
            if j == 2 && i + k < n do
              Map.put(acc, j, i + k)
            else
              if j == 3 && rem(i - 1, k) != k - 1 && i - 1 >= 0 do
                Map.put(acc, j, i - 1)
              else
                if j == 4 && rem(i + 1, k) != 0 && i + 1 < n do
                  Map.put(acc, j, i + 1)
                else
                  acc
                end
              end
            end
          end
        end)

      neighbours = Map.values(neighbours)

      neighbours =
        case topology do
          "imp2D" ->
            # :rand.uniform(n) gives random number: 1 <= x <= n
            neighbours ++ get_random_node(neighbours, i, n - 1)

          _ ->
            neighbours
        end

      neighbor_pids =
        Enum.map(neighbours, fn x ->
          {:ok, n} = Map.fetch(actors_with_index, x)
          n
        end)

      {:ok, actor} = Map.fetch(actors_with_index, i)
      Map.put(acc, actor, neighbor_pids)
    end)
  end

  # Create torus topology
  def torus_topology(actors) do
    n = length(actors)

    actors_with_index =
      Stream.with_index(actors, 0) |> Enum.reduce(%{}, fn {v, k}, acc -> Map.put(acc, k, v) end)

    ringSegments =
      cond do
        n >= 10000 ->
          1000

        n >= 1000 && n < 10000 ->
          100

        n < 1000 ->
          10
      end

    tubeSegments =
      cond do
        n >= 10000 ->
          trunc(:math.ceil(1 / 1000 * n))

        n >= 1000 && n < 10000 ->
          trunc(:math.ceil(1 / 100 * n))

        n < 1000 ->
          trunc(:math.ceil(1 / 10 * n))
      end

    Enum.reduce(0..(ringSegments - 1), %{}, fn r, acc ->
      Enum.reduce(0..(tubeSegments - 1), acc, fn t, acc ->
        i = r + t * ringSegments

        if(i < n) do
          neighbours = []
          neighbour1 = r - 1 + t * ringSegments

          neighbours =
            if(neighbour1 > 0 && neighbour1 < n) do
              neighbours ++ [neighbour1]
            else
              neighbours
            end

          neighbour2 = r + 1 + t * ringSegments

          neighbours =
            if(neighbour2 > 0 && neighbour2 < n) do
              neighbours ++ [neighbour2]
            else
              neighbours
            end

          neighbour3 = r - 1 + (t - 1) * ringSegments

          neighbours =
            if(neighbour3 > 0 && neighbour3 < n) do
              neighbours ++ [neighbour3]
            else
              neighbours
            end

          neighbour4 = r + 1 + (t + 1) * ringSegments

          neighbours =
            if(neighbour4 > 0 && neighbour4 < n) do
              neighbours ++ [neighbour4]
            else
              neighbours
            end

          neighbour5 = r + (t - 1) * ringSegments

          neighbours =
            if(neighbour5 > 0 && neighbour5 < n) do
              neighbours ++ [neighbour5]
            else
              neighbours
            end

          neighbour6 = r + (t + 1) * ringSegments

          neighbours =
            if(neighbour6 > 0 && neighbour6 < n) do
              neighbours ++ [neighbour6]
            else
              neighbours
            end

          neighbour7 = r + 1 + (t - 1) * ringSegments

          neighbours =
            if(neighbour7 > 0 && neighbour7 < n) do
              neighbours ++ [neighbour7]
            else
              neighbours
            end

          neighbour8 = r - 1 + (t + 1) * ringSegments

          neighbours =
            if(neighbour8 > 0 && neighbour8 < n) do
              neighbours ++ [neighbour8]
            else
              neighbours
            end

          neighbours = neighbours ++ get_random_node(neighbours, i, n - 1)

          neighbor_pids =
            Enum.map(neighbours, fn x ->
              {:ok, n} = Map.fetch(actors_with_index, x)
              n
            end)

          {:ok, actor} = Map.fetch(actors_with_index, i)
          Map.put(acc, actor, neighbor_pids)
        else
          acc
        end
      end)
    end)
  end

  # Create 3D topology
  def topology_3d(actors, topology) do
    n = length(actors)
    k = trunc(:math.ceil(cbrt(n)))

    actors_with_index =
      Stream.with_index(actors, 0) |> Enum.reduce(%{}, fn {v, k}, acc -> Map.put(acc, k, v) end)

    Enum.reduce(0..(n - 1), %{}, fn i, acc ->
      level = trunc(:math.floor(i / (k * k)))
      upperlimit = (level + 1) * k * k
      lowerlimit = level * k * k

      neighbours =
        Enum.reduce(1..6, %{}, fn j, acc ->
          if j == 1 && i - k >= lowerlimit do
            Map.put(acc, j, i - k)
          else
            if j == 2 && i + k < upperlimit && i + k < n do
              Map.put(acc, j, i + k)
            else
              if j == 3 && rem(i - 1, k) != k - 1 && i - 1 >= 0 do
                Map.put(acc, j, i - 1)
              else
                if j == 4 && rem(i + 1, k) != 0 && i + 1 < n do
                  Map.put(acc, j, i + 1)
                else
                  if j == 5 && i + k * k < n do
                    Map.put(acc, j, i + k * k)
                  else
                    if j == 6 && i - k * k >= 0 do
                      Map.put(acc, j, i - k * k)
                    else
                      acc
                    end
                  end
                end
              end
            end
          end
        end)

      neighbours = Map.values(neighbours)

      neighbours =
        case topology do
          # :rand.uniform(n) gives random number: 1 <= x <= n
          "imp3D" -> neighbours ++ get_random_node(neighbours, i, n - 1)
          _ -> neighbours
        end

      neighbor_pids =
        Enum.map(neighbours, fn x ->
          {:ok, n} = Map.fetch(actors_with_index, x)
          n
        end)

      {:ok, actor} = Map.fetch(actors_with_index, i)
      Map.put(acc, actor, neighbor_pids)
    end)
  end

  def set_neighbors(neighbors) do
    for {k, v} <- neighbors do
      Client.set_neighbors(k, v)
    end
  end

  def get_random_node(neighbors, i, numNodes) do
    random_node_index = :rand.uniform(numNodes)
    neighbors = neighbors ++ [i]

    if(Enum.member?(neighbors, random_node_index)) do
      get_random_node(neighbors, i, numNodes)
    else
      [random_node_index]
    end
  end

  # Spec to find cuberoot of a number
  @spec cbrt(number) :: number
  def cbrt(x) when is_number(x) do
    result = :math.pow(x, 1 / 3)

    cond do
      is_float(result) == false ->
        result

      true ->
        result_ceil = Float.ceil(result)
        result_14 = Float.round(result, 14)
        result_15 = Float.round(result, 15)

        if result_14 != result_15 and result_14 == result_ceil do
          result_14
        else
          result
        end
    end
  end
end
