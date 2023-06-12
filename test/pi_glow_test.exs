defmodule PiGlowTest do
  use ExUnit.Case, async: false
  import Mock

  alias Circuits.I2C

  setup [:define_mocks]

  describe "start_link/1" do
    test "opens device and enables LEDs", %{ref: ref, mocks: mocks} do
      with_mock(I2C, mocks) do
        assert {:ok, _pid} = PiGlow.start_link()

        assert_called(I2C.open("i2c-1"))
        assert_called(I2C.write(ref, 0x54, <<0, 1>>))
        assert_called(I2C.write(ref, 0x54, <<0x13, 0x3F, 0x3F, 0x3F>>))
        assert_called(I2C.write(ref, 0x54, <<0x16, 0xFF>>))

        shutdown()
      end
    end
  end

  describe "stop/0" do
    setup [:start]

    test "disables LEDs and closes I2C", %{ref: ref, mocks: mocks} do
      with_mock(I2C, mocks) do
        PiGlow.stop()

        assert_called(I2C.write(ref, 0x54, <<0x13, 0, 0, 0>>))
        assert_called(I2C.write(ref, 0x54, <<0x16, 0xFF>>))

        assert_receive :closed
        assert_called(I2C.close(ref))
      end
    end
  end

  describe "set_leds/1" do
    setup [:start]

    test "sets LEDs to given binary values", %{ref: ref, mocks: mocks} do
      with_mock(I2C, mocks) do
        PiGlow.set_leds("eighteenbytebinary")
        PiGlow.wait()

        assert_called(I2C.write(ref, 0x54, <<0x01, "eighteenbytebinary">>))
        assert_called(I2C.write(ref, 0x54, <<0x16, 0xFF>>))

        shutdown()
      end
    end

    test "sets LEDs to given values as list", %{ref: ref, mocks: mocks} do
      with_mock(I2C, mocks) do
        values = 0..255 |> Enum.shuffle() |> Enum.take(18)
        PiGlow.set_leds(values)
        PiGlow.wait()

        assert [
                 {pid, {I2C, :write, [^ref, 0x54, <<0x01, values_bin::binary>>]}, :ok},
                 {pid, {I2C, :write, [^ref, 0x54, <<0x16, 0xFF>>]}, :ok}
               ] = call_history(I2C)

        assert :erlang.binary_to_list(values_bin) == values

        shutdown()
      end
    end
  end

  describe "map_leds/1" do
    setup [:start]

    test "calls given function for every LED", %{mocks: mocks} do
      with_mock(I2C, mocks) do
        me = self()

        PiGlow.map_leds(fn led ->
          send(me, {:led, led})
          0
        end)

        PiGlow.LED.leds()
        |> Enum.each(fn led ->
          assert_receive {:led, ^led}
        end)

        refute_receive {:led, _}

        shutdown()
      end
    end

    test "sets LEDs based on result of function call", %{ref: ref, mocks: mocks} do
      with_mock(I2C, mocks) do
        PiGlow.map_leds(fn led -> led.arm * 10 + led.ring end)
        PiGlow.wait()

        values = <<36, 35, 34, 33, 12, 13, 16, 15, 14, 11, 21, 22, 31, 23, 32, 24, 25, 26>>
        assert_called(I2C.write(ref, 0x54, <<0x01>> <> values))
        assert_called(I2C.write(ref, 0x54, <<0x16, 0xFF>>))

        shutdown()
      end
    end
  end

  defp define_mocks(_ctx) do
    ref = make_ref()
    me = self()

    [
      ref: ref,
      mocks: [
        open: fn _dev -> {:ok, ref} end,
        write: fn ^ref, _addr, _bytes -> :ok end,
        close: fn ^ref ->
          send(me, :closed)
          :ok
        end
      ]
    ]
  end

  defp start(%{mocks: mocks}) do
    with_mock(Circuits.I2C, mocks) do
      assert {:ok, pid} = PiGlow.start_link()
      [pid: pid]
    end
  end

  defp shutdown do
    PiGlow.stop()
    assert_receive :closed
  end
end
