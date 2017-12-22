defmodule StructuredIO.Mixfile do
  use Mix.Project

  def project do
    [
      app: :structured_io,
      version: version(),
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5",  only: :dev, runtime: false},
      {:ex_doc,   "~> 0.18", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [extras: ["README.md":  [filename: "about",   title: "Project readme"],
              "License.md": [filename: "license", title: "Project license"],
              "History.md": [filename: "history", title: "Project history"]],
     # logo: "assets/logo.png",
     main: "about"]
  end

  defp version, do: "0.1.0"
end
