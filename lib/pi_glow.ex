defmodule PiGlow do
  require Logger
  @log_prefix "[#{inspect(__MODULE__)}] "

  @leds PiGlow.LED.leds() |> Enum.sort_by(& &1.index)
  @led_count 18 = Enum.count(@leds)
  @enable_chunk_size 6
  @enable_bytes 3 = div(@led_count, @enable_chunk_size)

  @moduledoc """
  A module for changing the power and brightness of the LEDs on a PiGlow device.

  Each PiGlow device contains #{@led_count} LEDs.  (See `PiGlow.LED` for a
  list.)  At any given time, each LED has two hardware properties:

    * **`enable`:** Whether power is being supplied to the LED, expressed as `1`/`true` or `0`/`false`.
    * **`power`:** The amount of power (via [PWM](https://en.wikipedia.org/wiki/Pulse-width_modulation)) being supplied to the LED, expressed as an integer between `0` (no power) and `255` (max power).

  Note that **these properties are independent of each other.**  An LED with
  `enabled` set to `true` may still be turned off if `power` is set to `0`.
  Similarly, an LED with `power` set to `255` will also still be turned off if
  `enable` is set to `false`.

  In general, the easiest way to use this library is to set all LEDs to
  `enable` = `true` when your application starts, and then simply adjust the
  `power` values (using `0` to turn them off).  (This is how most other PiGlow
  libraries work.)  However, having access to both properties allows for useful
  tricks, such as using `set_enable/1` to flash the lights on and off — without
  changing their brightness, and while allowing some lights to remain off
  (`power` = `0`).

  To set these properties, three levels of API are available:

    * **low:** Calling `set_*` with binary arguments.  This will send raw bytes to the device.
    * **medium:** Calling `set_*` with a list of values for each LED (in order).  This will convert those values to the appropriate binaries, and send them using the "low" method above.
    * **high:** Calling `map_*` with a function that maps each `PiGlow.LED` structure to a value.  This will create a list of values, which will be sent via the "medium" method above.

  Thus, you can choose whichever approach works best for your application — for
  example, based on efficiency versus complexity.

  ## Asynchronous API

  With the exception of `start_link/1`, `wait/1` and `stop/1`, all functions in
  this module are asynchronous — they cast messages to the running `PiGlow`
  instance without waiting for a reply, and they always return `:ok`.

  Aside from generally improving performance, this also allows rapidly queuing
  up multiple instructions, e.g. iterating through the full brigtness range
  (from 0 to 255 and back) to "pulse" the LEDs, allowing the PiGlow instance to
  run at full speed without waits.

  In situations where you need to ensure that all your prior instructions have
  completed execution, you can call `wait/1` to send a synchronous request to
  the instance.  This will block until the PiGlow instance has finished
  processing its current message queue.

  ## Process lifecycle

  You generally won't need to start a PiGlow instance manually, as starting
  the application will (by default) automatically start a named instance,
  unless you set `config :pi_glow, start: false` in your application config.

  If you do choose to manually launch a PiGlow instance, all functions in
  this module (besides `start_link`) accept an optional `pid` argument that can
  be used to specify either the PID or registered name of your launched
  instance.

  Note that **launching or shutting down a PiGlow instance does not change the
  state of the LEDs**.  (This is in contrast with other PiGlow libraries, which
  generally apply power to all LEDs on startup, and may also remove power on
  exit.)  Unless you know the LEDs are already enabled for some other reason,
  you'll want to use one of the `*_enable` functions before any `*_power`
  changes will be visible.

  If you are using this library in a script (rather than a daemon), note also
  that **when a script finishes and exits, all in-flight messages are
  discarded**.  If your script makes changes to the LEDs and then immediately
  exits, there's a good chance that most or all of your changes will never get
  processed.  If you want to run LED events just before exiting — for example,
  to turn them off — be sure to use `wait/1` or `stop/1` before exiting.
  """

  use GenServer, restart: :transient
  use PiGlow.AliasI2C

  @default_name __MODULE__

  @default_bus 1
  @bus_addr 0x54
  @cmd_enable_output 0x00
  @cmd_set_pwm_values 0x01
  @cmd_enable_leds 0x13
  @cmd_update 0x16

  @doc """
  Starts a process that will update the PiGlow device LEDs when it receives messages.

  ## Options

    * `:bus` - I2C bus device number (default: `#{@default_bus}`)
    * `:name` - Registered process name to use (default: `#{inspect(@default_name)}`)
      * Use value `nil` to prevent registration.

  This function also accepts all the options accepted by `GenServer.start_link/3`.

  ## Return values

  Same as `GenServer.start_link/3`.
  """
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {bus_id, opts} = Keyword.pop(opts, :bus, @default_bus)
    opts = Keyword.put_new(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, bus_id, opts)
  end

  @async_return_value """
  Always returns `:ok` immediately (even if there is no `PiGlow` process
  running).  Use `wait/1` if you need to ensure your changes have been sent to
  the device.
  """

  @doc """
  Enables or disables power to each LED.

  The `values` argument can be specified one of two ways:

    * As a list of #{@led_count} booleans, with `true` or `false` indicating
      whether each LED should be enabled or disabled.

    * As a #{@enable_bytes}-byte binary, where each byte is a
      #{@enable_chunk_size}-bit integer indicating which LEDs should be enabled.

  Note that LEDs require both `enabled = true` **and** `power > 0` to light up.
  Use `set_power/1` to adjust LED power, or `set_enabled_and_power/1` to set
  both in a single operation.

  #{@async_return_value}

  ## Examples

      # Enable LEDs at indices 1, 2, 3, 5, 8, 13:
      iex> 1..18 |> Enum.map(&(&1 in [1, 2, 3, 5, 8, 13])) |> PiGlow.set_enable()
      :ok

      # Equivalent to:
      iex> PiGlow.set_enable(<<0b111010, 0b010000, 0b100000>>)
      :ok
  """
  @type enable :: [boolean] | binary
  @spec set_enable(enable, pid) :: :ok
  def set_enable(values, pid \\ @default_name) do
    GenServer.cast(pid, {:set_enable, to_enable_binary(values)})
  end

  defp to_enable_binary(<<binary::binary-size(@enable_bytes)>>), do: binary

  defp to_enable_binary(list) when is_list(list) do
    list
    |> Enum.chunk_every(@enable_chunk_size)
    |> Enum.map(&bools_to_bits/1)
    |> :erlang.list_to_binary()
  end

  @doc """
  Sets the amount of power being delivered to each LED.

  The `values` argument can be specified one of two ways:

    * As a list of #{@led_count} integers, ranging from `0` (off) to `255` (full power).

    * As an #{@led_count}-byte binary, where each byte is an integer, as above.

  Note that LEDs require both `enabled = true` **and** `power > 0` to light up.
  Use `set_enable/1` to turn LEDs on, or `set_enabled_and_power/1` to set both
  in a single operation.

  #{@async_return_value}

  ## Examples

      # Set all LEDs to minimum brightness:
      iex> 1..18 |> Enum.map(fn _ -> 1 end) |> PiGlow.set_power()
      :ok

      # Equivalent to:
      iex> PiGlow.set_power(<<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>)
      :ok
  """
  @type power :: [integer] | binary
  @spec set_power(power, pid) :: :ok
  def set_power(values, pid \\ @default_name) do
    GenServer.cast(pid, {:set_power, to_power_binary(values)})
  end

  defp to_power_binary(<<binary::binary-size(@led_count)>>), do: binary
  defp to_power_binary(list) when is_list(list), do: list |> :erlang.list_to_binary()

  @doc """
  Enables or disables power to all LEDs, and sets the amount of power, in a single operation.

  The `values` argument can be specified one of two ways:

    * As a list of #{@led_count} two-element tuples, each in the format `{enable, power}`, where enable is a boolean and power is an integer.

    * As a two-element tuple, in the format `{enable_values, power_values}`.
      * `enable_values` can be in either format (binary or list) accepted by `set_enable/1`.
      * `power_values` can be in either format (binary or list) accepted by `set_power/1`.

  When using this function, both instructions are sent to the I2C controller,
  one immediately after the other, with no "update" operation sent inbetween.
  This should avoid any unexpected LED flickering caused by setting each value
  independently.

  #{@async_return_value}

  ## Examples

      # Set all LEDs to minimum brightness:
      iex> 1..18 |> Enum.map(fn _ -> 1 end) |> PiGlow.set_power()
      :ok

      # Equivalent to:
      iex> PiGlow.set_power(<<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>)
      :ok
  """
  @spec set_enable_and_power([{boolean, integer}] | {enable, power}, pid) :: :ok
  def set_enable_and_power(values, pid \\ @default_name)

  def set_enable_and_power({enable, power}, pid) do
    GenServer.cast(pid, {:set_enable_and_power, to_enable_binary(enable), to_power_binary(power)})
  end

  def set_enable_and_power([{_, _} | _] = list, pid) do
    Enum.unzip(list)
    |> set_enable_and_power(pid)
  end

  @doc """
  Run a function to determine which LEDs should have power enabled or disabled.

  The `fun` argument must be a function that takes one argument (a `PiGlow.LED`
  structure) and returns a boolean.  The resulting list of booleans will then
  be sent to `set_enable/1`.  See that function for more info.

  Returns `:ok` immediately.

  ## Examples

      # Turn on the green and blue LEDs, turn off the rest:
      iex> PiGlow.map_enable(fn led -> led.colour in [:green, :blue] end)
      :ok

      # Turn on five LEDs at random:
      iex> leds = PiGlow.LED.leds() |> Enum.take_random(5)
      iex> PiGlow.map_enable(&(&1 in leds))
      :ok
  """
  @spec map_enable((PiGlow.LED.t() -> boolean), pid) :: :ok
  def map_enable(fun, pid \\ @default_name) when is_function(fun) do
    @leds
    |> Enum.map(fun)
    |> set_enable(pid)
  end

  @doc """
  Run a function to determine how much power to send to each LED.

  The `fun` argument must be a function that takes one argument (a `PiGlow.LED`
  structure) and returns an integer in the range of `0..255`.  The resulting
  list of integers will then be sent to `set_power/1`.  See that function for
  more info.

  Returns `:ok` immediately.

  ## Examples

      # Set all LEDs to random brightness:
      iex> PiGlow.map_power(fn _ -> Enum.random(1..255) end)
      :ok

      # Set the first arm to max brightness, the second to medium, the third to minimum.
      iex> PiGlow.map_power(fn
      ...>   %{arm: 1} -> 255
      ...>   %{arm: 2} -> 125
      ...>   %{arm: 3} -> 1
      ...> end)
      :ok
  """
  @spec map_power((PiGlow.LED.t() -> integer), pid) :: :ok
  def map_power(fun, pid \\ @default_name) when is_function(fun) do
    @leds
    |> Enum.map(fun)
    |> set_power(pid)
  end

  @doc """
  Run a function to determine the enable status and power to send to each LED.

  The `fun` argument must be a function that takes one argument (a `PiGlow.LED`
  structure) and returns a 2-element tuple `{enable, power}`, where `enable` is
  a boolean and `power` is an integer in the range of `0..255`.

  The resulting list of boolean-integer pairs will be unzipped and sent to
  `set_enable_and_power/1`.  See that function for more info.

  Returns `:ok` immediately.

  ## Examples

      # Enable red LEDs at max brightness, amber at min brightness, disable the rest.
      iex> PiGlow.map_enable_and_power(fn
      ...>   %{colour: :red} -> {true, 255}
      ...>   %{colour: :amber} -> {true, 1}
      ...>   _ -> {false, 0}
      ...> end)
      :ok
  """
  @spec map_enable_and_power((PiGlow.LED.t() -> {boolean, integer}), pid) :: :ok
  def map_enable_and_power(fun, pid \\ @default_name) when is_function(fun) do
    @leds
    |> Enum.map(fun)
    |> set_enable_and_power(pid)
  end

  @doc """
  Waits for all prior messages to be received and processed.

  Returns `:ok` once all pending messages are processed.  (Note that this does
  not guarantee that the PiGlow is idle, only that messages sent prior to the
  start of this `wait` call have been processed.)

  If no message is received within `timeout` milliseconds (default: 60
  seconds), the caller will exit, as per standard `GenServer.call/2` semantics.

  ## Examples

      # Pulse all lights once:
      iex> [0..255, 255..0] |>
      ...>   Enum.flat_map(&Enum.to_list/1) |>
      ...>   Enum.map(&PiGlow.LED.gamma_correct/1) |>
      ...>   Enum.each(fn value ->
      ...>     PiGlow.map_power(fn _ -> value end)
      ...>   end)
      :ok

      # Wait for those 512 events to all be processed:
      iex> PiGlow.wait()
      :ok
  """
  @spec wait(timeout, pid) :: :ok
  def wait(timeout \\ 60_000, pid \\ @default_name) do
    GenServer.call(pid, :wait, timeout)
  end

  @doc """
  Stops a running instance and releases the I2C device.

  Returns `:ok` once all pending messages are processed and the instance has
  been cleanly stopped.

  Note that `PiGlow` uses a default restart policy of `:transient`, meaning
  that it will not be automatically restarted if stopped via this function.

  If no message is received within `timeout` milliseconds (default: 60
  seconds), the caller will exit.

  ## Examples

      # Turn off all LEDs, then shut it down:
      iex> PiGlow.map_enable_and_power(fn _ -> {false, 0} end)
      :ok
      iex> PiGlow.stop()
      :ok
  """
  @spec stop(timeout, pid) :: :ok
  def stop(timeout \\ 60_000, pid \\ @default_name) do
    GenServer.stop(pid, :normal, timeout)
  end

  # --- Internal functions ---

  @impl true
  def init(bus_id) when bus_id in 0..99 do
    case I2C.open("i2c-#{bus_id}") do
      {:ok, bus} ->
        spawn_cleanup(bus)
        :ok = I2C.write(bus, @bus_addr, <<@cmd_enable_output, 1>>)
        {:ok, bus}

      {:error, :bus_not_found} ->
        Logger.error(@log_prefix <> "I2C bus not found: /dev/i2c-#{bus_id}")
        :ignore

      {:error, err} ->
        Logger.error(@log_prefix <> "Unknown error opening I2C bus #{bus_id}: #{inspect(err)}")
        :ignore
    end
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
  def handle_cast(
        {:set_enable_and_power, <<enable::binary-size(@enable_bytes)>>,
         <<power::binary-size(@led_count)>>},
        bus
      ) do
    :ok = I2C.write(bus, @bus_addr, <<@cmd_enable_leds>> <> enable)
    :ok = I2C.write(bus, @bus_addr, <<@cmd_set_pwm_values>> <> power)
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
