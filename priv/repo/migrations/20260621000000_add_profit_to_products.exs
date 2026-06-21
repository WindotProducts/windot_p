defmodule WindotProducts.Repo.Migrations.AddProfitToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :profit, :integer, null: false, default: 0
    end
  end
end
