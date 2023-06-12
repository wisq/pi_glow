defmodule PiGlow.LEDTest do
  use ExUnit.Case, async: true

  alias PiGlow.LED

  test "there are eighteen lights" do
    assert LED.leds()
           |> Enum.map(& &1.index)
           |> Enum.sort() == 1..18 |> Enum.to_list()
  end

  test "gamma_correct handles integer values from 0 to 255" do
    corrected = 0..255 |> Enum.map(&LED.gamma_correct/1)

    assert corrected |> Enum.all?(&is_integer/1)
    assert corrected == Enum.sort(corrected)
    assert [0, 1, 1] = corrected |> Enum.take(3)
    assert [255, 250, 244] = corrected |> Enum.reverse() |> Enum.take(3)
  end

  test "gamma_correct handles float values from 0.0 to 1.0" do
    corrected = 0..1000 |> Enum.map(fn m -> LED.gamma_correct(m / 1000) end)

    assert corrected |> Enum.all?(&is_integer/1)
    assert corrected == Enum.sort(corrected)
    assert [0, 1, 1] = corrected |> Enum.take(3)
    assert [255, 254, 252] = corrected |> Enum.reverse() |> Enum.take(3)
  end
end
