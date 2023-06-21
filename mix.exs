defmodule CpuUtil.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpu_util,
      version: "0.5.1",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "CpuUtil",
      package: package(),
      docs: [
        main: "CpuUtil",
        extras: ["README.md", "LICENSE.md"]
      ],
      description: """
      Get CPU Utilization information on Linux systems.
      """
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.22.0", override: true, only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Stephen Pallen"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/infinityoneframework/cpu_util"},
      files: ~w(lib README.md mix.exs LICENSE.md)
    ]
  end
end
