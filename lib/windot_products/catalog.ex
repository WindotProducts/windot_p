defmodule WindotProducts.Catalog do
  @moduledoc """
  Database-backed catalog for materials and products.
  """

  import Ecto.Query, only: [from: 2]

  alias WindotProducts.Repo
  alias WindotProducts.Catalog.{Material, Product}

  def list_materials do
    Repo.all(from(material in Material, order_by: [asc: material.position, asc: material.id]))
  end

  def list_products do
    Product
    |> from(order_by: [asc: :position, asc: :id])
    |> Repo.all()
    |> Repo.preload(:items)
  end

  def get_material(id) when is_integer(id) do
    Repo.get(Material, id)
  end

  def get_product(id) when is_integer(id) do
    case Repo.get(Product, id) do
      nil -> nil
      product -> Repo.preload(product, :items)
    end
  end

  def upsert_material(attrs) when is_map(attrs) do
    {id, attrs} = extract_id(attrs)

    material =
      case id && Repo.get(Material, id) do
        %Material{} = record -> record
        _ -> %Material{}
      end

    attrs = maybe_put_position(attrs, material, Material)

    material
    |> Material.changeset(attrs)
    |> Repo.insert_or_update()
    |> unwrap_result()
  end

  def move_material(id, direction) when direction in [:up, :down] do
    move_record(Material, id, direction)
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
    attrs = maybe_put_position(attrs, %Product{}, Product)

    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
    |> unwrap_result(preload: [:items])
  end

  def upsert_product(attrs) when is_map(attrs) do
    {id, attrs} = extract_id(attrs)

    product =
      case id && get_product(id) do
        %Product{} = record -> record
        _ -> %Product{}
      end

    attrs = maybe_put_position(attrs, product, Product)

    product
    |> Product.changeset(attrs)
    |> Repo.insert_or_update()
    |> unwrap_result(preload: [:items])
  end

  def move_product(id, direction) when direction in [:up, :down] do
    move_record(Product, id, direction)
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

  defp maybe_put_position(attrs, %{id: nil}, schema) do
    Map.put_new(attrs, :position, next_position(schema))
  end

  defp maybe_put_position(attrs, _record, _schema), do: attrs

  defp next_position(schema) do
    max_position = Repo.one(from(record in schema, select: max(record.position)))
    (max_position || 0) + 1
  end

  defp move_record(schema, id, direction) do
    records = Repo.all(from(record in schema, order_by: [asc: record.position, asc: record.id]))
    index = Enum.find_index(records, &(&1.id == id))

    with index when is_integer(index) <- index,
         target_index <- move_target_index(index, direction),
         true <- target_index >= 0 and target_index < length(records),
         record <- Enum.at(records, index),
         target <- Enum.at(records, target_index) do
      Repo.transaction(fn ->
        swap_position(record, target)
        :ok
      end)

      :ok
    else
      _ -> :ok
    end
  end

  defp move_target_index(index, :up), do: index - 1
  defp move_target_index(index, :down), do: index + 1

  defp swap_position(record, target) do
    record_position = record.position

    record
    |> Ecto.Changeset.change(position: target.position)
    |> Repo.update!()

    target
    |> Ecto.Changeset.change(position: record_position)
    |> Repo.update!()
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
