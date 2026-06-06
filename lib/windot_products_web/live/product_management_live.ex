defmodule WindotProductsWeb.ProductManagementLive do
  @moduledoc false

  use WindotProductsWeb, :live_view

  alias WindotProducts.Catalog

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "مدیریت محصولات ویندات")
      |> assign(:current_scope, nil)
      |> assign(:active_tab, :materials)
      |> assign(:editing_material_id, nil)
      |> assign(:material_errors, %{})
      |> assign(:product_errors, [])
      |> assign(:product_items, [])
      |> assign(:material_form, material_form(%{}))
      |> assign(:product_form, product_form(%{}))
      |> assign(:item_form, item_form(%{}))
      |> refresh_materials()
      |> refresh_products()

    {:ok, socket}
  end

  @impl true
  def handle_event("set-tab", %{"tab" => tab}, socket) do
    active_tab = if tab == "products", do: :products, else: :materials

    socket =
      socket
      |> refresh_materials()
      |> refresh_products()
      |> assign(:active_tab, active_tab)

    {:noreply, socket}
  end

  def handle_event("material-validate", %{"material" => params}, socket) do
    {attrs, errors} = validate_material(params)

    {:noreply,
     socket
     |> assign(:material_form, material_form(params))
     |> assign(:material_errors, errors)
     |> assign(:editing_material_id, Map.get(attrs, :id))}
  end

  def handle_event("material-save", %{"material" => params}, socket) do
    {attrs, errors} = validate_material(params)

    if errors == %{} do
      _material = Catalog.upsert_material(attrs)
      {:noreply, reset_material_form(refresh_materials(socket))}
    else
      {:noreply,
       socket
       |> assign(:material_errors, errors)
       |> assign(:material_form, material_form(params))}
    end
  end

  def handle_event("material-edit", %{"id" => id}, socket) do
    case parse_int(id) do
      nil ->
        {:noreply, socket}

      material_id ->
        case Catalog.get_material(material_id) do
          nil ->
            {:noreply, socket}

          material ->
            socket =
              socket
              |> assign(:editing_material_id, material_id)
              |> assign(:material_form, material_form(material))
              |> assign(:material_errors, %{})

            {:noreply, socket}
        end
    end
  end

  def handle_event("material-cancel", _params, socket) do
    {:noreply, reset_material_form(socket)}
  end

  def handle_event("material-delete", %{"id" => id}, socket) do
    case parse_int(id) do
      nil ->
        {:noreply, socket}

      material_id ->
        :ok = Catalog.delete_material(material_id)

        socket =
          socket
          |> refresh_materials()
          |> refresh_products()
          |> drop_missing_items()

        {:noreply, socket}
    end
  end

  def handle_event("item-add", %{"item" => params}, socket) do
    material_id = parse_int(Map.get(params, "material_id"))
    quantity = parse_int(Map.get(params, "quantity"))

    socket =
      cond do
        is_nil(material_id) or is_nil(quantity) or quantity <= 0 ->
          assign(socket, :product_errors, ["لطفا متریال و مقدار معتبر وارد کنید."])

        is_nil(Map.get(socket.assigns.materials_by_id, material_id)) ->
          assign(socket, :product_errors, ["ابتدا متریال را ثبت کنید."])

        true ->
          updated_items = add_item(socket.assigns.product_items, material_id, quantity)

          socket
          |> assign(:product_items, updated_items)
          |> assign(:product_errors, [])
          |> assign(:item_form, item_form(%{"material_id" => "", "quantity" => ""}))
      end

    {:noreply, socket}
  end

  def handle_event("item-remove", %{"material_id" => id}, socket) do
    case parse_int(id) do
      nil ->
        {:noreply, socket}

      material_id ->
        items = Enum.reject(socket.assigns.product_items, &(&1.material_id == material_id))
        {:noreply, assign(socket, :product_items, items)}
    end
  end

  def handle_event("product-save", %{"product" => params}, socket) do
    name = String.trim(Map.get(params, "name", ""))
    items = socket.assigns.product_items

    cond do
      name == "" ->
        {:noreply, assign(socket, :product_errors, ["نام محصول الزامی است."])}

      items == [] ->
        {:noreply, assign(socket, :product_errors, ["حداقل یک متریال اضافه کنید."])}

      true ->
        _product = Catalog.add_product(%{name: name, items: items})

        socket =
          socket
          |> refresh_products()
          |> assign(:product_items, [])
          |> assign(:product_form, product_form(%{}))
          |> assign(:product_errors, [])

        {:noreply, socket}
    end
  end

  def handle_event("product-delete", %{"id" => id}, socket) do
    case parse_int(id) do
      nil ->
        {:noreply, socket}

      product_id ->
        :ok = Catalog.delete_product(product_id)
        {:noreply, refresh_products(socket)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-sm text-emerald-200/80">مدیریت هوشمند متریال و محصولات ویندات</p>
            <h1 class="neon-title text-2xl sm:text-3xl">پنل مدیریت محصولات</h1>
          </div>
          <div class="flex items-center gap-3">
            <div class="neon-pill">
              <span class="text-xs">{length(@materials_list)} متریال</span>
            </div>
            <div class="neon-pill">
              <span class="text-xs">{@products_count} محصول</span>
            </div>
          </div>
        </div>

        <div class="flex flex-wrap gap-3">
          <button
            type="button"
            class={tab_class(@active_tab == :materials)}
            phx-click="set-tab"
            phx-value-tab="materials"
          >
            متریال
          </button>
          <button
            type="button"
            class={tab_class(@active_tab == :products)}
            phx-click="set-tab"
            phx-value-tab="products"
          >
            محصولات
          </button>
        </div>

        <div :if={@active_tab == :materials} class="grid gap-8 lg:grid-cols-[1.1fr,0.9fr]">
          <section class="neon-card space-y-6">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-emerald-100">لیست متریال</h2>
              <span class="text-xs text-emerald-200/80">قیمت ها به تومان ثبت می شوند</span>
            </div>
            <div id="materials" class="space-y-4" phx-update="stream">
              <div
                :for={{dom_id, material} <- @streams.materials}
                id={dom_id}
                class="neon-row"
              >
                <div class="space-y-1">
                  <p class="text-sm text-emerald-200/70">نام متریال</p>
                  <p class="text-base font-semibold text-slate-50">{material.name}</p>
                </div>
                <div class="space-y-1">
                  <p class="text-sm text-emerald-200/70">واحد شمارش</p>
                  <p class="text-base text-emerald-50">{material.unit}</p>
                </div>
                <div class="space-y-1">
                  <p class="text-sm text-emerald-200/70">قیمت</p>
                  <p class="text-base font-semibold text-lime-200">{price_toman(material.price)}</p>
                </div>
                <div class="flex flex-wrap items-center justify-end gap-2">
                  <button
                    type="button"
                    class="neon-btn neon-btn-soft"
                    phx-click="material-edit"
                    phx-value-id={material.id}
                  >
                    ویرایش
                  </button>
                  <button
                    type="button"
                    class="neon-btn neon-btn-danger"
                    phx-click="material-delete"
                    phx-value-id={material.id}
                  >
                    حذف
                  </button>
                </div>
              </div>
            </div>
          </section>

          <section class="neon-card">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-emerald-100">
                {if @editing_material_id, do: "ویرایش متریال", else: "ثبت متریال جدید"}
              </h2>
              <button
                :if={@editing_material_id}
                type="button"
                class="neon-link"
                phx-click="material-cancel"
              >
                انصراف
              </button>
            </div>

            <.form
              for={@material_form}
              id="material-form"
              class="mt-6 space-y-4"
              phx-change="material-validate"
              phx-submit="material-save"
            >
              <.input type="hidden" field={@material_form[:id]} />
              <.input
                field={@material_form[:name]}
                label="نام متریال"
                errors={Map.get(@material_errors, :name, [])}
                class="neon-input"
                error_class="neon-input-error"
              />
              <.input
                field={@material_form[:unit]}
                label="واحد شمارش"
                errors={Map.get(@material_errors, :unit, [])}
                class="neon-input"
                error_class="neon-input-error"
              />
              <.input
                field={@material_form[:price]}
                type="number"
                label="قیمت هر واحد (تومان)"
                errors={Map.get(@material_errors, :price, [])}
                class="neon-input"
                error_class="neon-input-error"
                min="0"
              />
              <button type="submit" class="neon-btn w-full">
                {if @editing_material_id, do: "ذخیره تغییرات", else: "ثبت متریال"}
              </button>
            </.form>
          </section>
        </div>

        <div :if={@active_tab == :products} class="grid gap-8 lg:grid-cols-[1.1fr,0.9fr]">
          <section class="neon-card space-y-6">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-emerald-100">لیست محصولات</h2>
              <span class="text-xs text-emerald-200/80">قیمت کل از جمع متریال ها</span>
            </div>

            <div id="products" class="space-y-6" phx-update="stream">
              <div
                :for={{dom_id, product} <- @streams.products}
                id={dom_id}
                class="neon-row flex-col items-start gap-4"
              >
                <div class="flex w-full flex-wrap items-start justify-between gap-4">
                  <div>
                    <p class="text-sm text-emerald-200/70">نام محصول</p>
                    <p class="text-lg font-semibold text-slate-50">{product.name}</p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm text-emerald-200/70">قیمت کل محصول</p>
                    <p class="text-lg font-semibold text-lime-200">
                      {price_toman(product_total(product, @materials_by_id))}
                    </p>
                  </div>
                </div>

                <div class="w-full space-y-3">
                  <p class="text-sm font-semibold text-emerald-100">متریال های مصرفی</p>
                  <div class="space-y-2">
                    <%= for item <- product.items do %>
                      <%= if material = Map.get(@materials_by_id, item.material_id) do %>
                        <div class="neon-subrow">
                          <div>
                            <p class="text-sm text-emerald-200/70">{material.name}</p>
                            <p class="text-xs text-emerald-200/60">
                              واحد: {item.quantity} {material.unit}
                            </p>
                          </div>
                          <p class="text-sm font-semibold text-lime-200">
                            {price_toman(material.price * item.quantity)}
                          </p>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                </div>

                <div class="flex w-full justify-end">
                  <button
                    type="button"
                    class="neon-btn neon-btn-danger"
                    phx-click="product-delete"
                    phx-value-id={product.id}
                  >
                    حذف محصول
                  </button>
                </div>
              </div>
            </div>
          </section>

          <section class="neon-card">
            <h2 class="text-lg font-semibold text-emerald-100">ساخت محصول جدید</h2>
            <div class="mt-6 space-y-4">
              <.form for={@product_form} id="product-form" class="space-y-4" phx-submit="product-save">
                <.input
                  field={@product_form[:name]}
                  label="نام محصول"
                  class="neon-input"
                  error_class="neon-input-error"
                />
              </.form>

              <div class="neon-divider" />

              <div class="space-y-3">
                <p class="text-sm font-semibold text-emerald-100">افزودن متریال به محصول</p>
                <.form
                  for={@item_form}
                  id="item-form"
                  phx-submit="item-add"
                  class="grid gap-3 sm:grid-cols-[1.3fr,0.7fr,auto]"
                >
                  <.input
                    field={@item_form[:material_id]}
                    type="select"
                    label="متریال"
                    options={material_options(@materials_list)}
                    prompt="انتخاب متریال"
                    class="neon-input"
                    error_class="neon-input-error"
                  />
                  <.input
                    field={@item_form[:quantity]}
                    type="number"
                    label="مقدار مصرف"
                    class="neon-input"
                    error_class="neon-input-error"
                    min="1"
                  />
                  <button type="submit" class="neon-btn mt-6 sm:mt-7">افزودن</button>
                </.form>
              </div>

              <div :if={@product_errors != []} class="neon-alert">
                <%= for message <- @product_errors do %>
                  <p>{message}</p>
                <% end %>
              </div>

              <div class="space-y-3">
                <p class="text-sm font-semibold text-emerald-100">متریال های انتخاب شده</p>
                <div class="space-y-2">
                  <div
                    :for={item <- @product_items}
                    class="neon-subrow"
                  >
                    <div>
                      <p class="text-sm text-emerald-200/70">
                        {material_name(item.material_id, @materials_by_id)}
                      </p>
                      <p class="text-xs text-emerald-200/60">
                        مقدار: {item.quantity}
                      </p>
                    </div>
                    <button
                      type="button"
                      class="neon-link"
                      phx-click="item-remove"
                      phx-value-material_id={item.material_id}
                    >
                      حذف
                    </button>
                  </div>
                </div>
              </div>

              <button type="submit" form="product-form" class="neon-btn w-full">ثبت محصول</button>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp validate_material(params) do
    id = parse_int(Map.get(params, "id"))
    name = String.trim(Map.get(params, "name", ""))
    unit = String.trim(Map.get(params, "unit", ""))
    price = parse_int(Map.get(params, "price"))

    errors = %{}

    errors =
      if name == "" do
        Map.put(errors, :name, ["نام متریال الزامی است."])
      else
        errors
      end

    errors =
      if unit == "" do
        Map.put(errors, :unit, ["واحد شمارش الزامی است."])
      else
        errors
      end

    errors =
      if is_nil(price) or price < 0 do
        Map.put(errors, :price, ["قیمت باید عدد معتبر باشد."])
      else
        errors
      end

    {%{id: id, name: name, unit: unit, price: price}, errors}
  end

  defp material_form(%{} = params) do
    params
    |> stringify_keys()
    |> to_form(as: "material")
  end

  defp product_form(%{} = params) do
    params
    |> stringify_keys()
    |> to_form(as: "product")
  end

  defp item_form(%{} = params) do
    params
    |> stringify_keys()
    |> to_form(as: "item")
  end

  defp stringify_keys(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  defp material_options(materials) do
    Enum.map(materials, fn material ->
      {material.name, material.id}
    end)
  end

  defp add_item(items, material_id, quantity) do
    case Enum.find(items, &(&1.material_id == material_id)) do
      nil ->
        items ++ [%{material_id: material_id, quantity: quantity}]

      existing ->
        updated = %{existing | quantity: existing.quantity + quantity}
        Enum.map(items, fn item -> if item.material_id == material_id, do: updated, else: item end)
    end
  end

  defp material_name(material_id, materials_by_id) do
    case Map.get(materials_by_id, material_id) do
      nil -> "متریال حذف شده"
      material -> material.name
    end
  end

  defp product_total(product, materials_by_id) do
    Enum.reduce(product.items, 0, fn item, acc ->
      case Map.get(materials_by_id, item.material_id) do
        nil -> acc
        material -> acc + material.price * item.quantity
      end
    end)
  end

  defp price_toman(amount) when is_integer(amount) do
    formatted =
      amount
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/(.{3})(?=.)/, "\\1,")
      |> String.reverse()

    formatted <> " تومان"
  end

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp refresh_materials(socket) do
    materials = Catalog.list_materials()

    socket
    |> assign(:materials_list, materials)
    |> assign(:materials_by_id, materials_by_id(materials))
    |> stream(:materials, materials, reset: true)
  end

  defp refresh_products(socket) do
    products = Catalog.list_products()

    socket
    |> assign(:products_count, length(products))
    |> stream(:products, products, reset: true)
  end

  defp reset_material_form(socket) do
    socket
    |> assign(:editing_material_id, nil)
    |> assign(:material_form, material_form(%{}))
    |> assign(:material_errors, %{})
  end

  defp drop_missing_items(socket) do
    items =
      Enum.filter(socket.assigns.product_items, fn item ->
        Map.has_key?(socket.assigns.materials_by_id, item.material_id)
      end)

    assign(socket, :product_items, items)
  end

  defp materials_by_id(materials) do
    Enum.reduce(materials, %{}, fn material, acc -> Map.put(acc, material.id, material) end)
  end

  defp tab_class(active?) do
    if active? do
      "neon-tab neon-tab-active"
    else
      "neon-tab"
    end
  end
end
