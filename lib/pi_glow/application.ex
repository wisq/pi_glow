defmodule PiGlow.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        if(Application.get_env(:pi_glow, :start, true), do: PiGlow, else: nil),
        if(Application.get_env(:pi_glow, :start_mock_i2c, false), do: MockI2C, else: nil)
      ]
      |> Enum.reject(&is_nil/1)

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
