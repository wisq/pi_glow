defmodule PiGlowTest do
  use ExUnit.Case
  doctest PiGlow

  test "greets the world" do
    assert PiGlow.hello() == :world
  end
end
