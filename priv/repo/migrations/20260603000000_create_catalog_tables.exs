defmodule WindotProducts.Repo.Migrations.CreateCatalogTables do
  use Ecto.Migration

  def change do
    create table(:materials) do
      add :name, :string, null: false
      add :unit, :string, null: false
      add :price, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:products) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:product_items) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :material_id, references(:materials, on_delete: :delete_all), null: false
      add :quantity, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:product_items, [:product_id])
    create index(:product_items, [:material_id])
    create unique_index(:product_items, [:product_id, :material_id])
  end
end
