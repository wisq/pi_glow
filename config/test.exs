import Config

config :pi_glow,
  start: false,
  start_mock_i2c: true,
  i2c_module: MockI2C

config :logger, level: :info
