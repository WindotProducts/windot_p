defmodule WindotProducts.Repo.Migrations.AddPositionToCatalogTables do
  use Ecto.Migration

  def change do
    alter table(:materials) do
      add :position, :integer, null: false, default: 0
    end

    alter table(:products) do
      add :position, :integer, null: false, default: 0
    end

    execute(
      """
      UPDATE materials
      SET position = ordered.row_number
      FROM (
        SELECT id, row_number() OVER (ORDER BY id) AS row_number
        FROM materials
      ) AS ordered
      WHERE materials.id = ordered.id
      """,
      ""
    )

    execute(
      """
      UPDATE products
      SET position = ordered.row_number
      FROM (
        SELECT id, row_number() OVER (ORDER BY id) AS row_number
        FROM products
      ) AS ordered
      WHERE products.id = ordered.id
      """,
      ""
    )

    create index(:materials, [:position])
    create index(:products, [:position])
  end
end
