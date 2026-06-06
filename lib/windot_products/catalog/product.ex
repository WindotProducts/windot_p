defmodule WindotProducts.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string

    has_many :items, WindotProducts.Catalog.ProductItem, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_assoc(:items, with: &WindotProducts.Catalog.ProductItem.changeset/2)
    |> validate_length(:items, min: 1)
  end
end
