defmodule PiGlowDocTest do
  use ExUnit.Case, async: false

  setup :start
  doctest PiGlow

  defp start(_ctx) do
    assert {:ok, _} = PiGlow.start_link()
    []
  end
end

defmodule PiGlowTest do
  use ExUnit.Case, async: true

  describe "start_link/1" do
    test "opens I2C device and enables I2C writing" do
      assert {:ok, pid} = PiGlow.start_link(name: nil)

      assert i2c = MockI2C.get_device(pid)
      assert i2c.device == "i2c-1"
      assert i2c.writes == [{0x54, <<0, 1>>}]
    end
  end

  describe "stop/0" do
    setup [:start]

    test "closes I2C", %{pid: pid, i2c: i2c} do
      assert !i2c.closed

      PiGlow.stop(1_000, pid)
      assert i2c = MockI2C.wait_for_close(i2c.ref)
      assert i2c.writes == []
      assert i2c.closed
    end
  end

  describe "set_enable/1" do
    setup [:start]

    test "sets LED on/off status to given binary values", %{pid: pid} do
      PiGlow.set_enable(<<0x11, 0x22, 0x33>>, pid)
      PiGlow.wait(1_000, pid)

      assert MockI2C.get_device(pid).writes == [
               {0x54, <<0x13, 0x11, 0x22, 0x33>>},
               {0x54, <<0x16, 0xFF>>}
             ]
    end

    test "sets LED on/off status to given values as list", %{pid: pid} do
      values =
        [
          # Byte 1: 0b101010 = 42
          [true, false, true, false, true, false],
          # Byte 2: 0b111111 = 63
          [true, true, true, true, true, true],
          # Byte 3: 0b011001 = 25
          [false, true, true, false, false, true]
        ]
        |> List.flatten()

      PiGlow.set_enable(values, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x13, values_bin::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      assert values_bin == <<42, 63, 25>>
    end
  end

  describe "set_power/1" do
    setup [:start]

    test "sets LED power to given binary values", %{pid: pid} do
      PiGlow.set_power("eighteenbytebinary", pid)
      PiGlow.wait(1_000, pid)

      assert MockI2C.get_device(pid).writes == [
               {0x54, <<0x01, "eighteenbytebinary">>},
               {0x54, <<0x16, 0xFF>>}
             ]
    end

    test "sets LED power to given values as list", %{pid: pid} do
      values = 0..255 |> Enum.shuffle() |> Enum.take(18)
      PiGlow.set_power(values, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x01, values_bin::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      assert :erlang.binary_to_list(values_bin) == values
    end
  end

  describe "set_enable_and_power/1" do
    setup [:start]

    test "sets LED on/off and power to given binary values", %{pid: pid} do
      PiGlow.set_enable_and_power({<<0x12, 0x23, 0x34>>, "arbitraryPWMvalues"}, pid)
      PiGlow.wait(1_000, pid)

      assert MockI2C.get_device(pid).writes == [
               {0x54, <<0x13, 0x12, 0x23, 0x34>>},
               {0x54, <<0x01, "arbitraryPWMvalues">>},
               {0x54, <<0x16, 0xFF>>}
             ]
    end

    test "sets LED on/off and power to given values as list of tuples", %{pid: pid} do
      values =
        [
          # Byte 1: 0b100110 = 38
          [true: 104, false: 242, false: 173, true: 228, true: 236, false: 164],
          # Byte 2: 0b010011 = 19
          [false: 227, true: 104, false: 8, false: 222, true: 223, true: 29],
          # Byte 3: 0b111101 = 61
          [true: 255, true: 67, true: 119, true: 10, false: 115, true: 252]
        ]
        |> List.flatten()

      PiGlow.set_enable_and_power(values, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x13, enable::binary>>},
               {0x54, <<0x01, power::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      assert enable == <<38, 19, 61>>

      assert power ==
               [
                 <<104, 242, 173, 228, 236, 164>>,
                 <<227, 104, 8, 222, 223, 29>>,
                 <<255, 67, 119, 10, 115, 252>>
               ]
               |> Enum.join("")
    end
  end

  describe "map_enable/1" do
    setup [:start]

    test "calls given function for every LED", %{pid: pid} do
      me = self()

      PiGlow.map_enable(
        fn led ->
          send(me, {:led, led})
          true
        end,
        pid
      )

      PiGlow.LED.leds()
      |> Enum.each(fn led ->
        assert_receive {:led, ^led}
      end)

      refute_receive {:led, _}
    end

    test "sets LED enable based on result of function call", %{pid: pid} do
      PiGlow.map_enable(fn led -> led.colour in [:red, :amber] end, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x13, values::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      # Enabled LED indices: [1, 3, 7, 9, 16, 18]
      assert values == <<0b101000, 0b101000, 0b000101>>
    end
  end

  describe "map_power/1" do
    setup [:start]

    test "calls given function for every LED", %{pid: pid} do
      me = self()

      PiGlow.map_power(
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

    test "sets LED power based on result of function call", %{pid: pid} do
      PiGlow.map_power(fn led -> led.arm * 10 + led.ring end, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x01, values::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      assert values == <<36, 35, 34, 33, 12, 13, 16, 15, 14, 11, 21, 22, 31, 23, 32, 24, 25, 26>>
    end
  end

  describe "map_enable_and_power/1" do
    setup [:start]

    test "calls given function for every LED", %{pid: pid} do
      me = self()

      PiGlow.map_enable_and_power(
        fn led ->
          send(me, {:led, led})
          {true, 255}
        end,
        pid
      )

      PiGlow.LED.leds()
      |> Enum.each(fn led ->
        assert_receive {:led, ^led}
      end)

      refute_receive {:led, _}
    end

    test "sets LED power based on result of function call", %{pid: pid} do
      fun = fn led ->
        ena = led.ring in 2..4
        pow = led.ring * 5 + led.arm
        {ena, pow}
      end

      PiGlow.map_enable_and_power(fun, pid)
      PiGlow.wait(1_000, pid)

      assert [
               {0x54, <<0x13, enable::binary>>},
               {0x54, <<0x01, power::binary>>},
               {0x54, <<0x16, 0xFF>>}
             ] = MockI2C.get_device(pid).writes

      # Enabled LED indices: [3, 4, 5, 6, 9, 12, 14, 15, 16]
      assert enable == <<0b001111, 0b001001, 0b011100>>
      assert power == <<33, 28, 23, 18, 11, 16, 31, 26, 21, 6, 7, 12, 8, 17, 13, 22, 27, 32>>
    end
  end

  defp start(_ctx) do
    assert {:ok, pid} = PiGlow.start_link(name: nil)
    assert i2c = MockI2C.reset_writes(pid)
    [pid: pid, i2c: i2c, ref: i2c.ref]
  end
end
