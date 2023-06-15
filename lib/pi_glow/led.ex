defmodule PiGlow.LED do
  @moduledoc """
  A structure representing a single LED on a PiGlow device.

  These are the values that the `PiGlow.map_*` functions pass to the
  user-supplied function.  Your application code can choose which LEDs to
  operate on by looking at the LED's properties:

    * `index` — the position of the LED in the binary versions of `PiGlow.set_enable` and `PiGlow.set_power`
    * `arm` — which of the three arms the LED is on (clockwise)
      * `1` — the top arm, directly below the "PiGlow" text
      * `2` — the right arm, on the side with the Pimoroni URL
      * `3` — the left arm, on the side with the small text and icons
    * `ring` — how far from the centre the LED is, in the range of `1..6`
    * `colour` — the LED colour, as an atom

  Note that `ring` and `colour` are effectively the same value, just expressed two different ways:

    * ring `1` corresponds to colour `:white`
    * ring `2` corresponds to colour `:blue`
    * ring `3` corresponds to colour `:green`
    * ring `4` corresponds to colour `:amber`
    * ring `5` corresponds to colour `:orange`
    * ring `6` corresponds to colour `:red`

  Additionally, this module also contains utility functions relating to LEDs
  and LED brightness.
  """

  alias __MODULE__

  @enforce_keys [:index, :arm, :colour, :ring]
  defstruct(
    index: nil,
    arm: nil,
    ring: nil,
    colour: nil
  )

  @type colour :: :white | :blue | :green | :amber | :orange | :red

  @type t :: %__MODULE__{
          index: 1..18,
          arm: 1..3,
          ring: 1..6,
          colour: colour
        }

  @doc """
  Return the list of LEDs on a PiGlow device.

  ## Examples

      # Find all green LEDs:
      iex> PiGlow.LED.leds() |> Enum.filter(fn led -> led.colour == :green end)
      [
        %PiGlow.LED{index: 6, arm: 1, ring: 3, colour: :green},
        %PiGlow.LED{index: 14, arm: 2, ring: 3, colour: :green},
        %PiGlow.LED{index: 4, arm: 3, ring: 3, colour: :green}
      ]
  """
  @spec leds :: [t]
  def leds do
    [
      # Top arm:
      %LED{index: 0x0A, arm: 1, ring: 1, colour: :white},
      %LED{index: 0x05, arm: 1, ring: 2, colour: :blue},
      %LED{index: 0x06, arm: 1, ring: 3, colour: :green},
      %LED{index: 0x09, arm: 1, ring: 4, colour: :amber},
      %LED{index: 0x08, arm: 1, ring: 5, colour: :orange},
      %LED{index: 0x07, arm: 1, ring: 6, colour: :red},
      # Right arm:
      %LED{index: 0x0B, arm: 2, ring: 1, colour: :white},
      %LED{index: 0x0C, arm: 2, ring: 2, colour: :blue},
      %LED{index: 0x0E, arm: 2, ring: 3, colour: :green},
      %LED{index: 0x10, arm: 2, ring: 4, colour: :amber},
      %LED{index: 0x11, arm: 2, ring: 5, colour: :orange},
      %LED{index: 0x12, arm: 2, ring: 6, colour: :red},
      # Left arm:
      %LED{index: 0x0D, arm: 3, ring: 1, colour: :white},
      %LED{index: 0x0F, arm: 3, ring: 2, colour: :blue},
      %LED{index: 0x04, arm: 3, ring: 3, colour: :green},
      %LED{index: 0x03, arm: 3, ring: 4, colour: :amber},
      %LED{index: 0x02, arm: 3, ring: 5, colour: :orange},
      %LED{index: 0x01, arm: 3, ring: 6, colour: :red}
    ]
  end

  @doc """
  Calculates the power value needed to approximate a given brightness.

  The relationship between how much power is sent to an LED, and how bright
  that LED actually shines, is a non-linear one — i.e. going from 90% to 95% of
  max brightness requires a significantly larger increase in energy than going
  from 5% to 10% of max brightness.  This function attempts to correct for that
  by applying an exponential curve to the supplied brightness value.

  The `value` argument can be either an integer between `0` and `255`
  inclusive, or a float between `0.0` and `1.0` inclusive.  The result will
  follow this pattern:

    * `gamma_correct(v) = 0` when `v` is `0` or `0.0`
    * `gamma_correct(v) = 255` when `v` is `255` or `1.0`
    * otherwise, `gamma_correct(v)` will follow an exponential curve from `1` to `255`

  Returns an integer in the range of `0..255`, which can be passed to the
  `power`-based functions in `PiGlow`.

  ## Examples

      # Pulse all lights once:
      iex> [0..255, 255..0] |>
      ...>   Enum.flat_map(&Enum.to_list/1) |>
      ...>   Enum.map(&PiGlow.LED.gamma_correct/1) |>
      ...>   Enum.each(fn value ->
      ...>     PiGlow.map_power(fn _ -> value end)
      ...>   end)
      :ok
  """
  @spec gamma_correct(0..255 | float) :: 0..255
  def gamma_correct(value)
  def gamma_correct(0.0), do: 0

  def gamma_correct(i) when is_integer(i) and i >= 0 and i <= 255 do
    gamma_correct(i / 255)
  end

  def gamma_correct(f) when is_float(f) and f >= 0.0 and f <= 1.0 do
    Float.pow(255.0, f)
    |> round()
  end
end
