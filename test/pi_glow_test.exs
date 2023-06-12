defmodule PiGlowTest do
  use ExUnit.Case, async: true

  describe "start_link/1" do
    test "opens device and enables LEDs" do
      assert {:ok, pid} = PiGlow.start_link(name: nil)

      assert i2c = MockI2C.get_device(pid)
      assert i2c.device == "i2c-1"

      assert i2c.writes == [
               {0x54, <<0, 1>>},
               {0x54, <<0x13, 0x3F, 0x3F, 0x3F>>},
               {0x54, <<0x16, 0xFF>>}
             ]
    end
  end

  describe "stop/0" do
    setup [:start]

    test "disables LEDs and closes I2C", %{pid: pid, i2c: i2c} do
      assert !i2c.closed

      PiGlow.stop(1_000, pid)
      assert i2c = MockI2C.wait_for_close(i2c.ref)

      assert i2c.writes == [
               {0x54, <<0x13, 0, 0, 0>>},
               {0x54, <<0x16, 0xFF>>}
             ]

      assert i2c.closed
    end
  end

  describe "set_leds/1" do
    setup [:start]

    test "sets LEDs to given binary values", %{pid: pid} do
      PiGlow.set_leds("eighteenbytebinary", pid)
      PiGlow.wait(1_000, pid)

      assert MockI2C.get_device(pid).writes == [
               {0x54, <<0x01, "eighteenbytebinary">>},
               {0x54, <<0x16, 0xFF>>}
             ]
    end

    test "sets LEDs to given values as list", %{pid: pid} do
      values = 0..255 |> Enum.shuffle() |> Enum.take(18)
      PiGlow.set_leds(values, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x01, values_bin::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      assert :erlang.binary_to_list(values_bin) == values
    end
  end

  describe "map_leds/1" do
    setup [:start]

    test "calls given function for every LED", %{pid: pid} do
      me = self()

      PiGlow.map_leds(
        fn led ->
          send(me, {:led, led})
          0
        end,
        pid
      )

      PiGlow.LED.leds()
      |> Enum.each(fn led ->
        assert_receive {:led, ^led}
      end)

      refute_receive {:led, _}
    end

    test "sets LEDs based on result of function call", %{pid: pid} do
      PiGlow.map_leds(fn led -> led.arm * 10 + led.ring end, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x01, values::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      assert values == <<36, 35, 34, 33, 12, 13, 16, 15, 14, 11, 21, 22, 31, 23, 32, 24, 25, 26>>
    end
  end

  defp start(_ctx) do
    assert {:ok, pid} = PiGlow.start_link(name: nil)
    assert i2c = MockI2C.reset_writes(pid)
    [pid: pid, i2c: i2c, ref: i2c.ref]
  end
end
