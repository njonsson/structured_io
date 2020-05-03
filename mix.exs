defmodule StructuredIO.Mixfile do
  use Mix.Project

  def project do
    [
      app: :structured_io,
      version: version(),
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      source_url: "https://github.com/njonsson/structured_io",
      homepage_url: "https://njonsson.github.io/structured_io",
      preferred_cli_env: %{
        :coveralls => :test,
        :"coveralls.detail" => :test,
        :"coveralls.html" => :test,
        :"coveralls.json" => :test,
        :"coveralls.post" => :test
      },
      test_coverage: [tool: ExCoveralls],
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12", only: :test, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "README.md": [filename: "about", title: "Project readme"],
        "License.md": [filename: "license", title: "Project license"],
        "History.md": [filename: "history", title: "Project history"]
      ],
      # logo: "assets/logo.png",
      main: "about"
    ]
  end

  defp description, do: "An Elixir API for consuming structured input streams"

  defp package do
    [
      files: ~w{History.md
                     License.md
                     README.md
                     lib
                     mix.exs},
      maintainers: ["Nils Jonsson <structured-io@nilsjonsson.com>"],
      licenses: ["MIT"],
      links: %{
        "Home" => "https://njonsson.github.io/structured_io",
        "Source" => "https://github.com/njonsson/structured_io",
        "Issues" => "https://github.com/njonsson/structured_io/issues"
      }
    ]
  end

  defp version, do: "0.12.0"
end
