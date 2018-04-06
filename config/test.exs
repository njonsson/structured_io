use Mix.Config

config :ex_unit, exclude: :slow
config :logger, :console, level: :warn, metadata: [:all]
