defmodule PiGlow.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = if Application.get_env(:pi_glow, :start, true), do: [PiGlow], else: []
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
