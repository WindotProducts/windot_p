defmodule WindotProducts.Repo do
  use Ecto.Repo,
    otp_app: :windot_products,
    adapter: Ecto.Adapters.Postgres
end
