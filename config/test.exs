use Mix.Config

config :ex_unit, exclude: :slow
config :logger, :console, level: :info, metadata: [:all]
