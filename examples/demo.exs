#
# Plays a few patterns in sequence.
#
# Run this using `mix run examples/demo.exs`
#

alias PiGlow.LED

long_pulse =
  [0..255, 255..0]
  |> Enum.flat_map(& &1)
  |> Enum.map(&PiGlow.LED.gamma_correct/1)

short_pulse =
  [0..255//3, 255..0//3]
  |> Enum.flat_map(& &1)
  |> Enum.map(&PiGlow.LED.gamma_correct/1)

# Turn on all the LEDs:
PiGlow.map_enable_and_power(fn _ -> {true, 0} end)

# Do three long pulses of all the LEDs at once:
1..3
|> Enum.flat_map(fn _ -> long_pulse end)
|> Enum.each(fn v -> PiGlow.map_power(fn _led -> v end) end)

# Do short pulses by ring -- outside to inside, back to outside -- repeated three times:
[6..1, 2..6, 5..1, 2..6, 5..1, 2..6]
|> Enum.flat_map(&Enum.to_list/1)
|> Enum.each(fn ring ->
  short_pulse
  |> Enum.map(fn v ->
    PiGlow.map_power(fn
      %LED{ring: ^ring} -> v
      _ -> 0
    end)
  end)
end)

# Cycle through the arms, doing short pulses for each in turn, nine times:
1..9
|> Enum.flat_map(fn _ -> 1..3 end)
|> Enum.each(fn arm ->
  short_pulse
  |> Enum.map(fn v ->
    PiGlow.map_power(fn
      %LED{arm: ^arm} -> v
      _ -> 0
    end)
  end)
end)

# All of the above events were delivered asynchronously, as fast as we could
# generate them.
#
# So at this point in the execution, there's a whole bunch of light events
# still in flight to the PiGlow process.  If we just exit here, it will end the
# entire program, and the lights will be in some random state based on where
# they were when we exited.
#
# Let's set all the LEDs to off, and wait for the process to catch up:
PiGlow.map_enable(fn _ -> false end)
IO.puts("All events sent, waiting for completion.")

# Note that we could also run PiGlow.stop() here instead, since we're exiting anyway.
PiGlow.wait()
