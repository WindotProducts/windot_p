defmodule WindotProducts.Catalog.ProductItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_items" do
    field(:quantity, :integer)

    belongs_to(:material, WindotProducts.Catalog.Material)
    belongs_to(:product, WindotProducts.Catalog.Product)

    timestamps(type: :utc_datetime)
  end

  def changeset(product_item, attrs) do
    product_item
    |> cast(attrs, [:material_id, :quantity])
    |> validate_required([:material_id, :quantity])
    |> validate_number(:quantity, greater_than: 0)
  end
end
