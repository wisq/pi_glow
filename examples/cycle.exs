#
# Plays a continuous pattern whereby the rings light up in a bouncing in-out-in
# order, leaving a decaying trail behind them.
#
# Run this using `mix run examples/cycle.exs`
#

defmodule Cycler do
  # Decay each ring by 1 brightness per tick.
  @decay_rate 1
  # Move to the next ring every 100 ticks.
  @move_every 50
  # Start at the outermost ring.
  @first_ring 6

  def run do
    :ok = set_led_enable(true)

    spawn_link(fn ->
      1..@move_every
      |> Enum.to_list()
      |> Stream.cycle()
      |> Enum.reduce({@first_ring, [0, 0, 0, 0, 0, 0]}, &run_tick/2)
    end)
  end

  def stop(pid) do
    Process.exit(pid, :normal)
    :ok = set_led_enable(false)
  end

  defp run_tick(1, {ring, ring_values}) do
    # Wait so we don't endlessly fill the message box.
    wait_for_sync()

    ring_values =
      ring_values
      # Decay as normal.
      |> decay_rings()
      # Apply max brightness to the next ring.
      |> List.replace_at(abs(ring) - 1, 255)

    :ok = set_led_power(ring_values)

    {ring |> next_ring(), ring_values}
  end

  defp run_tick(_, {ring, ring_values}) do
    ring_values = ring_values |> decay_rings()

    :ok = set_led_power(ring_values)

    {ring, ring_values}
  end

  defp wait_for_sync do
    {us, :ok} = :timer.tc(PiGlow, :wait, [])
    IO.puts("Synced in #{us}µs  (press enter to exit)")
  end

  # Ring pattern goes in and out, then resets:
  defp next_ring(-5), do: -4
  defp next_ring(-4), do: -3
  defp next_ring(-3), do: -2
  defp next_ring(-2), do: 1
  defp next_ring(1), do: 2
  defp next_ring(2), do: 3
  defp next_ring(3), do: 4
  defp next_ring(4), do: 5
  defp next_ring(5), do: 6
  defp next_ring(6), do: -5

  defp decay_rings(rings) do
    rings
    |> Enum.map(fn
      0 -> 0
      v -> max(0, v - @decay_rate)
    end)
  end

  defp set_led_power(rings) do
    corrected = rings |> Enum.map(&PiGlow.LED.gamma_correct/1)
    PiGlow.map_power(fn led -> Enum.at(corrected, led.ring - 1) end)
  end

  defp set_led_enable(enable) do
    :ok = PiGlow.map_enable(fn _ -> enable end)
    :ok = PiGlow.wait()
  end
end

pid = Cycler.run()
IO.gets("")
Cycler.stop(pid)
