defmodule PiGlow do
  use GenServer, restart: :transient
  use PiGlow.AliasI2C

  @bus_addr 0x54
  @cmd_enable_output 0x00
  @cmd_set_pwm_values 0x01
  @cmd_enable_leds 0x13
  @cmd_update 0x16

  @leds PiGlow.LED.leds() |> Enum.sort_by(& &1.index)
  @led_count 18 = Enum.count(@leds)
  @enable_chunk_size 6
  @enable_bytes 3 = div(@led_count, @enable_chunk_size)

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def set_enable(values, pid \\ __MODULE__)

  def set_enable(<<bytes::binary-size(@enable_bytes)>>, pid) do
    GenServer.cast(pid, {:set_enable, bytes})
  end

  def set_enable(list, pid) when is_list(list) do
    list
    |> Enum.chunk_every(@enable_chunk_size)
    |> Enum.map(&bools_to_bits/1)
    |> :erlang.list_to_binary()
    |> set_enable(pid)
  end

  def set_power(values, pid \\ __MODULE__)

  def set_power(<<bytes::binary-size(18)>>, pid) do
    GenServer.cast(pid, {:set_power, bytes})
  end

  def set_power(list, pid) when is_list(list) do
    list
    |> :erlang.list_to_binary()
    |> set_power(pid)
  end

  def map_enable(fun, pid \\ __MODULE__) when is_function(fun) do
    @leds
    |> Enum.map(fun)
    |> set_enable(pid)
  end

  def map_power(fun, pid \\ __MODULE__) when is_function(fun) do
    @leds
    |> Enum.map(fun)
    |> set_power(pid)
  end

  def wait(timeout \\ 60_000, pid \\ __MODULE__) do
    GenServer.call(pid, :wait, timeout)
  end

  def stop(timeout \\ 60_000, pid \\ __MODULE__) do
    GenServer.stop(pid, :normal, timeout)
  end

  @impl true
  def init(_) do
    {:ok, bus} = I2C.open("i2c-1")
    spawn_cleanup(bus)
    :ok = I2C.write(bus, @bus_addr, <<@cmd_enable_output, 1>>)
    {:ok, bus}
  end

  @impl true
  def handle_cast({:set_enable, <<bytes::binary-size(@enable_bytes)>>}, bus) do
    :ok = I2C.write(bus, @bus_addr, <<@cmd_enable_leds>> <> bytes)
    :ok = update(bus)
    {:noreply, bus}
  end

  @impl true
  def handle_cast({:set_power, <<bytes::binary-size(@led_count)>>}, bus) do
    :ok = I2C.write(bus, @bus_addr, <<@cmd_set_pwm_values>> <> bytes)
    :ok = update(bus)
    {:noreply, bus}
  end

  @impl true
  def handle_call(:wait, _from, bus) do
    {:reply, :ok, bus}
  end

  defp spawn_cleanup(bus) do
    me = self()

    spawn(fn ->
      ref = Process.monitor(me)

      receive do
        {:DOWN, ^ref, :process, ^me, _} -> I2C.close(bus)
      end
    end)
  end

  defp update(bus), do: I2C.write(bus, @bus_addr, <<@cmd_update, 0xFF>>)

  defp bools_to_bits(list, acc \\ 0)
  defp bools_to_bits([], acc), do: acc
  defp bools_to_bits([true | rest], acc), do: bools_to_bits(rest, 2 * acc + 1)
  defp bools_to_bits([false | rest], acc), do: bools_to_bits(rest, 2 * acc)
end
