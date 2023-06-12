defmodule MockI2C do
  use GenServer

  defmodule DeviceState do
    @enforce_keys [:pid, :ref, :device]
    defstruct(
      pid: nil,
      ref: nil,
      device: nil,
      writes: [],
      closed: false,
      waiting_for_close: nil
    )

    def handle_get(%DeviceState{} = st) do
      %DeviceState{st | writes: Enum.reverse(st.writes)}
    end
  end

  @ets :mock_i2c_pids

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def open(device) do
    GenServer.call(__MODULE__, {:open, self(), device})
  end

  def close(ref) do
    GenServer.cast(__MODULE__, {:close, ref})
  end

  def write(ref, addr, bytes) do
    GenServer.cast(__MODULE__, {:write, ref, addr, bytes})
  end

  def get_device(pid_or_ref) do
    {:ok, i2c} = GenServer.call(__MODULE__, {:get, lookup_ref(pid_or_ref)})
    i2c |> DeviceState.handle_get()
  end

  def reset_writes(pid_or_ref) do
    {:ok, i2c} = GenServer.call(__MODULE__, {:reset_writes, lookup_ref(pid_or_ref)})
    i2c |> DeviceState.handle_get()
  end

  def wait_for_close(pid_or_ref) do
    {:ok, i2c} = GenServer.call(__MODULE__, {:wait_for_close, lookup_ref(pid_or_ref)})
    i2c |> DeviceState.handle_get()
  end

  @impl true
  def init(_) do
    :ets.new(@ets, [:named_table])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:open, pid, device}, _from, states) do
    ref = make_ref()
    dev = %DeviceState{pid: pid, ref: ref, device: device}
    :ets.insert(@ets, {pid, ref})
    {:reply, {:ok, ref}, Map.put(states, ref, dev)}
  end

  @impl true
  def handle_call({:get, ref}, _from, states) do
    {:reply, Map.fetch(states, ref), states}
  end

  @impl true
  def handle_call({:reset_writes, ref}, _from, states) do
    case Map.fetch(states, ref) do
      {:ok, %DeviceState{} = st} ->
        {:reply, {:ok, st}, Map.put(states, ref, %DeviceState{st | writes: []})}

      :error ->
        {:reply, :error, states}
    end
  end

  @impl true
  def handle_call({:wait_for_close, ref}, from, states) do
    case Map.fetch(states, ref) do
      {:ok, %DeviceState{closed: true} = st} ->
        {:reply, {:ok, st}, states}

      {:ok, %DeviceState{closed: false, waiting_for_close: nil} = st} ->
        {:noreply, Map.put(states, ref, %DeviceState{st | waiting_for_close: from})}

      :error ->
        {:reply, :error, states}
    end
  end

  @impl true
  def handle_cast({:close, ref}, states) do
    {:noreply,
     Map.update!(states, ref, fn
       %DeviceState{closed: false, waiting_for_close: waiting} = st ->
         st = %DeviceState{st | closed: true, waiting_for_close: nil}
         if waiting, do: GenServer.reply(waiting, {:ok, st})
         st
     end)}
  end

  @impl true
  def handle_cast({:write, ref, addr, bytes}, states) do
    {:noreply,
     Map.update!(states, ref, fn
       %DeviceState{writes: rest} = st -> %DeviceState{st | writes: [{addr, bytes} | rest]}
     end)}
  end

  defp lookup_ref(pid) when is_pid(pid) do
    [{^pid, ref}] = :ets.lookup(@ets, pid)
    ref
  end

  defp lookup_ref(ref) when is_reference(ref), do: ref
end
