defmodule PiGlow.LED do
  alias __MODULE__

  @enforce_keys [:index, :arm, :colour, :ring]
  defstruct(
    index: nil,
    arm: nil,
    ring: nil,
    colour: nil
  )

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

  def gamma_correct(0), do: 0

  def gamma_correct(v) when is_integer(v) do
    Float.pow(255.0, v / 255) |> round()
  end
end
