defmodule PiGlow do
  use GenServer
  alias Circuits.I2C

  @bus_addr 0x54
  @cmd_enable_output 0x00
  @cmd_set_pwm_values 0x01
  @cmd_enable_leds 0x13
  @cmd_update 0x16

  @leds PiGlow.LED.leds() |> Enum.sort_by(& &1.index)
  @led_count Enum.count(@leds)

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def set_leds(values, pid \\ __MODULE__)

  def set_leds(<<bytes::binary-size(18)>>, pid) do
    GenServer.cast(pid, {:set_leds, bytes})
  end

  def set_leds(list, pid) when is_list(list) do
    list
    |> :erlang.list_to_binary()
    |> set_leds(pid)
  end

  def map_leds(fun, pid \\ __MODULE__) when is_function(fun) do
    @leds
    |> Enum.map(fun)
    |> set_leds(pid)
  end

  @impl true
  def init(_) do
    {:ok, bus} = I2C.open("i2c-1")
    spawn_cleanup(bus)
    :ok = I2C.write(bus, @bus_addr, <<@cmd_enable_output, 1>>)
    :ok = I2C.write(bus, @bus_addr, <<@cmd_enable_leds, 0x3F, 0x3F, 0x3F>>)
    update(bus)
    {:ok, bus}
  end

  @impl true
  def handle_cast({:set_leds, <<_::binary-size(@led_count)>> = bytes}, bus) do
    :ok = I2C.write(bus, @bus_addr, <<@cmd_set_pwm_values>> <> bytes)
    :ok = update(bus)
    {:noreply, bus}
  end

  @impl true
  def terminate(_reason, bus) do
    I2C.write(bus, @bus_addr, <<@cmd_enable_leds, 0x00, 0x00, 0x00>>)
    update(bus)
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
end
