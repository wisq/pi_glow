defmodule PiGlow.MixProject do
  use Mix.Project

  @github_url "https://github.com/wisq/pi_glow"

  def project do
    [
      app: :pi_glow,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      source_url: @github_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PiGlow.Application, []}
    ]
  end

  defp description do
    """
    PiGlow is a library for controlling a "PiGlow" LED array device.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"],
      maintainers: ["Adrian Irving-Beer"],
      licenses: ["MIT"],
      links: %{GitHub: @github_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:circuits_i2c, "~> 1.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_git_test, "~> 0.1.2", only: [:dev, :test], runtime: false}
    ]
  end
end
