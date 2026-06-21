defmodule WindotProducts.Repo.Migrations.ChangeProductItemQuantityToFloat do
  use Ecto.Migration

  def change do
    alter table(:product_items) do
      modify :quantity, :float, null: false
    end
  end
end
