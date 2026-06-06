import Config

config :windot_products, WindotProducts.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "windot_products_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :windot_products, WindotProductsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "aQb1EhuAmym4DL7ZSXMJcEiCK0hGkEegvMSPsfndwZNhWdrRxQRx/9tkMN/38RIk",
  server: false

# In test we don't send emails
config :windot_products, WindotProducts.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
