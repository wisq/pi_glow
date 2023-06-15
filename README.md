# PiGlow

[![Hex.pm Version](https://img.shields.io/hexpm/v/pi_glow.svg?style=flat-square)](https://hex.pm/packages/pi_glow)

PiGlow is a library for controlling a [Pimoroni "PiGlow" LED array](https://shop.pimoroni.com/products/piglow).

With it, you can turn the LEDs on or off, and adjust their power output, allowing your Elixir daemon to give some fun visual feedback to the world around it.

## Installation

PiGlow requires Elixir v1.14.  To use it, add `:pi_glow` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pi_glow, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
# Set all LEDs to full power, but turned off:
PiGlow.map_enable_and_power(fn _ -> {false, 255} end)

# Turn on each arm in sequence:
1..3
|> Enum.each(fn arm ->
  PiGlow.map_enable(fn led -> led.arm == arm end)
  Process.sleep(1000)
end)

# Turn everything off:
PiGlow.map_enable_and_power(fn _ -> {false, 0} end)
# Wait before exiting:
PiGlow.wait()
```

More examples can be found in the [examples](https://github.com/wisq/pi_glow/tree/main/examples) directory.

## Documentation

Full documentation can be found at <https://hexdocs.pm/pi_glow>.

## Legal stuff

Copyright © 2023, Adrian Irving-Beer.

PiGlow is released under the [MIT license](https://github.com/wisq/pi_glow/blob/main/LICENSE) and is provided with **no warranty**.  I doubt it's possible to damage your PiGlow with this library, but if you do, I'm not responsible.
