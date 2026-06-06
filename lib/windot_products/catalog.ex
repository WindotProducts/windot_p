defmodule WindotProducts.Catalog do
  @moduledoc """
  Database-backed catalog for materials and products.
  """

  import Ecto.Query, only: [from: 2]

  alias WindotProducts.Repo
  alias WindotProducts.Catalog.{Material, Product}

  def list_materials do
    Repo.all(from material in Material, order_by: material.id)
  end

  def list_products do
    Product
    |> from(order_by: [asc: :id])
    |> Repo.all()
    |> Repo.preload(:items)
  end

  def get_material(id) when is_integer(id) do
    Repo.get(Material, id)
  end

  def upsert_material(attrs) when is_map(attrs) do
    {id, attrs} = extract_id(attrs)

    material =
      case id && Repo.get(Material, id) do
        %Material{} = record -> record
        _ -> %Material{}
      end

    material
    |> Material.changeset(attrs)
    |> Repo.insert_or_update()
    |> unwrap_result()
  end

  def delete_material(id) when is_integer(id) do
    case Repo.get(Material, id) do
      nil ->
        :ok

      material ->
        material
        |> Repo.delete()
        |> unwrap_result()
        :ok
    end
  end

  def add_product(attrs) when is_map(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
    |> unwrap_result(preload: [:items])
  end

  def delete_product(id) when is_integer(id) do
    case Repo.get(Product, id) do
      nil ->
        :ok

      product ->
        product
        |> Repo.delete()
        |> unwrap_result()
        :ok
    end
  end

  defp extract_id(attrs) do
    id = Map.get(attrs, :id) || Map.get(attrs, "id")

    id =
      cond do
        is_integer(id) ->
          id

        is_binary(id) ->
          case Integer.parse(id) do
            {value, ""} -> value
            _ -> nil
          end

        true ->
          nil
      end

    {id, Map.drop(attrs, [:id, "id"])}
  end

  defp unwrap_result(result, opts \\ [])

  defp unwrap_result({:ok, struct}, opts) do
    if opts[:preload] do
      Repo.preload(struct, opts[:preload])
    else
      struct
    end
  end

  defp unwrap_result({:error, changeset}, _opts), do: {:error, changeset}
end
