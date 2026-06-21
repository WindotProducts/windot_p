defmodule WindotProducts.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field(:name, :string)
    field(:profit, :integer, default: 0)
    field(:position, :integer, default: 0)

    has_many(:items, WindotProducts.Catalog.ProductItem, on_replace: :delete)

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :profit, :position])
    |> validate_required([:name, :profit, :position])
    |> validate_number(:profit, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> cast_assoc(:items, with: &WindotProducts.Catalog.ProductItem.changeset/2)
    |> validate_length(:items, min: 1)
  end
end
