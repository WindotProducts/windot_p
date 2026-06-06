defmodule WindotProducts.Catalog.Material do
  use Ecto.Schema
  import Ecto.Changeset

  schema "materials" do
    field :name, :string
    field :unit, :string
    field :price, :integer

    has_many :product_items, WindotProducts.Catalog.ProductItem

    timestamps(type: :utc_datetime)
  end

  def changeset(material, attrs) do
    material
    |> cast(attrs, [:name, :unit, :price])
    |> validate_required([:name, :unit, :price])
    |> validate_number(:price, greater_than_or_equal_to: 0)
  end
end
