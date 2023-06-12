defmodule PiGlow.AliasI2C do
  defmacro __using__(_opts) do
    module = Application.get_env(:pi_glow, :i2c_module, Circuits.I2C)

    quote do
      alias unquote(module), as: I2C
    end
  end
end
