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
      |> assign(:editing_product_id, nil)
      |> assign(:material_modal_open, false)
      |> assign(:product_modal_open, false)
      |> assign(:material_search, "")
      |> assign(:product_search, "")
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
      |> assign(:material_modal_open, false)
      |> assign(:product_modal_open, false)

    {:noreply, socket}
  end

  def handle_event("material-search", %{"search" => %{"q" => query}}, socket) do
    {:noreply,
     socket
     |> assign(:material_search, query)
     |> refresh_materials()}
  end

  def handle_event("product-search", %{"search" => %{"q" => query}}, socket) do
    {:noreply,
     socket
     |> assign(:product_search, query)
     |> refresh_products()}
  end

  def handle_event("material-new", _params, socket) do
    {:noreply,
     socket
     |> reset_material_form()
     |> assign(:material_modal_open, true)}
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

      socket =
        socket
        |> refresh_materials()
        |> refresh_products()
        |> reset_material_form()

      {:noreply, socket}
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
              |> assign(:material_modal_open, true)
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

  def handle_event("material-move", %{"id" => id, "direction" => direction}, socket) do
    with material_id when is_integer(material_id) <- parse_int(id),
         move_direction when move_direction in [:up, :down] <- parse_direction(direction) do
      Catalog.move_material(material_id, move_direction)
    end

    {:noreply, refresh_materials(socket)}
  end

  def handle_event("item-add", %{"item" => params}, socket) do
    material_ids =
      params
      |> Map.get("material_ids", [])
      |> List.wrap()
      |> Enum.map(&parse_int/1)
      |> Enum.reject(&is_nil/1)

    socket =
      cond do
        material_ids == [] ->
          assign(socket, :product_errors, ["لطفا حداقل یک متریال انتخاب کنید."])

        Enum.any?(material_ids, &is_nil(Map.get(socket.assigns.materials_by_id, &1))) ->
          assign(socket, :product_errors, ["ابتدا متریال را ثبت کنید."])

        true ->
          updated_items = add_items(socket.assigns.product_items, material_ids)

          socket
          |> assign(:product_items, updated_items)
          |> assign(:product_errors, [])
          |> assign(:item_form, item_form(%{}))
      end

    {:noreply, socket}
  end

  def handle_event("item-add", _params, socket) do
    {:noreply, assign(socket, :product_errors, ["لطفا حداقل یک متریال انتخاب کنید."])}
  end

  def handle_event("item-quantities-change", %{"items" => params}, socket) do
    items =
      Enum.map(socket.assigns.product_items, fn item ->
        quantity =
          params
          |> Map.get(to_string(item.material_id), %{})
          |> Map.get("quantity")
          |> parse_quantity()

        Map.put(item, :quantity, quantity)
      end)

    {:noreply, assign(socket, :product_items, items)}
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

  def handle_event("product-validate", %{"product" => params}, socket) do
    {:noreply, assign(socket, :product_form, product_form(params))}
  end

  def handle_event("product-new", _params, socket) do
    {:noreply,
     socket
     |> reset_product_form()
     |> assign(:product_modal_open, true)}
  end

  def handle_event("product-save", %{"product" => params}, socket) do
    product_id = parse_int(Map.get(params, "id"))
    name = String.trim(Map.get(params, "name", ""))
    profit = parse_int(Map.get(params, "profit"))
    items = socket.assigns.product_items

    cond do
      name == "" ->
        {:noreply,
         socket
         |> assign(:product_form, product_form(params))
         |> assign(:product_errors, ["نام محصول الزامی است."])}

      is_nil(profit) or profit < 0 ->
        {:noreply,
         socket
         |> assign(:product_form, product_form(params))
         |> assign(:product_errors, ["مبلغ سود باید عدد معتبر باشد."])}

      items == [] ->
        {:noreply,
         socket
         |> assign(:product_form, product_form(params))
         |> assign(:product_errors, ["حداقل یک متریال اضافه کنید."])}

      Enum.any?(items, &(is_nil(&1.quantity) or &1.quantity <= 0)) ->
        {:noreply,
         socket
         |> assign(:product_form, product_form(params))
         |> assign(:product_errors, ["برای همه متریال های انتخاب شده مقدار معتبر وارد کنید."])}

      true ->
        _product =
          Catalog.upsert_product(%{id: product_id, name: name, profit: profit, items: items})

        socket =
          socket
          |> refresh_products()
          |> reset_product_form()

        {:noreply, socket}
    end
  end

  def handle_event("product-edit", %{"id" => id}, socket) do
    case parse_int(id) do
      nil ->
        {:noreply, socket}

      product_id ->
        case Catalog.get_product(product_id) do
          nil ->
            {:noreply, socket}

          product ->
            items =
              Enum.map(product.items, fn item ->
                %{id: item.id, material_id: item.material_id, quantity: item.quantity}
              end)

            socket =
              socket
              |> assign(:active_tab, :products)
              |> assign(:editing_product_id, product_id)
              |> assign(:product_form, product_form(product))
              |> assign(:product_items, items)
              |> assign(:product_errors, [])
              |> assign(:product_modal_open, true)

            {:noreply, socket}
        end
    end
  end

  def handle_event("product-cancel", _params, socket) do
    {:noreply, reset_product_form(socket)}
  end

  def handle_event("product-delete", %{"id" => id}, socket) do
    case parse_int(id) do
      nil ->
        {:noreply, socket}

      product_id ->
        :ok = Catalog.delete_product(product_id)

        socket =
          socket
          |> refresh_products()
          |> maybe_reset_deleted_product(product_id)

        {:noreply, socket}
    end
  end

  def handle_event("product-move", %{"id" => id, "direction" => direction}, socket) do
    with product_id when is_integer(product_id) <- parse_int(id),
         move_direction when move_direction in [:up, :down] <- parse_direction(direction) do
      Catalog.move_product(product_id, move_direction)
    end

    {:noreply, refresh_products(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:header_badge>
        <span>{@products_count} محصول</span>
        <span>{length(@materials_list)} متریال</span>
      </:header_badge>

      <div class="space-y-4">
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

        <div :if={@active_tab == :materials} class="grid gap-3">
          <section class="neon-card space-y-3">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-emerald-100">لیست متریال</h2>
              <span class="text-xs text-emerald-200/80">قیمت ها به تومان ثبت می شوند</span>
            </div>

            <.form
              for={to_form(%{"q" => @material_search}, as: "search")}
              id="material-search-form"
              phx-change="material-search"
            >
              <.input
                type="search"
                name="search[q]"
                value={@material_search}
                label="جستجو بر اساس نام متریال"
                class="neon-input"
                phx-debounce="250"
              />
            </.form>

            <div id="materials" class="neon-counter space-y-1.5" phx-update="stream">
              <div
                :for={{dom_id, material} <- @streams.materials}
                id={dom_id}
                class="neon-row neon-row-numbered"
              >
                <div class="neon-index" aria-hidden="true"></div>

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

                <div class="neon-row-actions">
                  <div class="neon-row-actions-group">
                    <button
                      type="button"
                      class="neon-icon-btn"
                      title="انتقال به بالا"
                      aria-label="انتقال متریال به بالا"
                      phx-click="material-move"
                      phx-value-id={material.id}
                      phx-value-direction="up"
                    >
                      <.icon name="hero-arrow-up" class="size-4" />
                    </button>
                    <button
                      type="button"
                      class="neon-icon-btn"
                      title="انتقال به پایین"
                      aria-label="انتقال متریال به پایین"
                      phx-click="material-move"
                      phx-value-id={material.id}
                      phx-value-direction="down"
                    >
                      <.icon name="hero-arrow-down" class="size-4" />
                    </button>
                  </div>

                  <div class="neon-row-actions-group">
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
            </div>
          </section>

          <div :if={@material_modal_open} id="material-modal" class="neon-modal-backdrop">
            <section id="material-editor" class="neon-modal-panel">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-emerald-100">
                  {if @editing_material_id, do: "ویرایش متریال", else: "ثبت متریال جدید"}
                </h2>

                <button
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
                class="mt-4 space-y-3"
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
        </div>

        <div :if={@active_tab == :products} class="grid gap-3">
          <section class="neon-card space-y-3">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-emerald-100">لیست محصولات</h2>
              <span class="text-xs text-emerald-200/80">قیمت کل از جمع متریال ها و سود</span>
            </div>

            <.form
              for={to_form(%{"q" => @product_search}, as: "search")}
              id="product-search-form"
              phx-change="product-search"
            >
              <.input
                type="search"
                name="search[q]"
                value={@product_search}
                label="جستجو بر اساس نام محصول"
                class="neon-input"
                phx-debounce="250"
              />
            </.form>

            <div id="products" class="neon-counter space-y-2" phx-update="stream">
              <div
                :for={{dom_id, product} <- @streams.products}
                id={dom_id}
                class="neon-row neon-row-numbered items-start gap-2"
              >
                <div class="neon-index" aria-hidden="true"></div>

                <div class="space-y-1">
                  <p class="text-sm text-emerald-200/70">نام محصول</p>

                  <p class="text-base font-semibold text-slate-50">{product.name}</p>
                </div>

                <div class="space-y-1">
                  <p class="text-sm text-emerald-200/70">سود</p>

                  <p class="text-base text-emerald-50">{price_toman(product_profit(product))}</p>
                </div>

                <div class="space-y-1">
                  <p class="text-sm text-emerald-200/70">قیمت کل</p>

                  <p class="text-base font-semibold text-lime-200">
                    {price_toman(product_total(product, @materials_by_id))}
                  </p>
                </div>

                <div class="neon-row-actions">
                  <div class="neon-row-actions-group">
                    <button
                      type="button"
                      class="neon-icon-btn"
                      title="انتقال به بالا"
                      aria-label="انتقال محصول به بالا"
                      phx-click="product-move"
                      phx-value-id={product.id}
                      phx-value-direction="up"
                    >
                      <.icon name="hero-arrow-up" class="size-4" />
                    </button>
                    <button
                      type="button"
                      class="neon-icon-btn"
                      title="انتقال به پایین"
                      aria-label="انتقال محصول به پایین"
                      phx-click="product-move"
                      phx-value-id={product.id}
                      phx-value-direction="down"
                    >
                      <.icon name="hero-arrow-down" class="size-4" />
                    </button>
                  </div>

                  <div class="neon-row-actions-group">
                    <button
                      type="button"
                      class="neon-btn neon-btn-soft"
                      phx-click="product-edit"
                      phx-value-id={product.id}
                    >
                      ویرایش
                    </button>
                    <button
                      type="button"
                      class="neon-btn neon-btn-danger"
                      phx-click="product-delete"
                      phx-value-id={product.id}
                    >
                      حذف
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <div :if={@product_modal_open} id="product-modal" class="neon-modal-backdrop">
            <section id="product-editor" class="neon-modal-panel">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-emerald-100">
                  {if @editing_product_id, do: "ویرایش محصول", else: "ساخت محصول جدید"}
                </h2>
                <button
                  type="button"
                  class="neon-link"
                  phx-click="product-cancel"
                >
                  انصراف
                </button>
              </div>
              <div class="mt-3 space-y-2.5">
                <.form
                  for={@product_form}
                  id="product-form"
                  class="space-y-2.5"
                  phx-change="product-validate"
                  phx-submit="product-save"
                >
                  <.input type="hidden" field={@product_form[:id]} />
                  <.input
                    field={@product_form[:name]}
                    label="نام محصول"
                    class="neon-input"
                    error_class="neon-input-error"
                  />
                  <.input
                    field={@product_form[:profit]}
                    type="number"
                    label="سود محصول (تومان)"
                    class="neon-input"
                    error_class="neon-input-error"
                    min="0"
                  />
                </.form>
                <div class="neon-divider" />
                <div class="space-y-2">
                  <p class="text-sm font-semibold text-emerald-100">افزودن متریال به محصول</p>

                  <.form
                    for={@item_form}
                    id="item-form"
                    phx-submit="item-add"
                    class="space-y-2.5"
                  >
                    <div class="grid gap-2 sm:grid-cols-2">
                      <label
                        :for={material <- available_materials(@materials_list, @product_items)}
                        for={"material-option-#{material.id}"}
                        class="neon-check"
                      >
                        <input
                          type="checkbox"
                          id={"material-option-#{material.id}"}
                          name="item[material_ids][]"
                          value={material.id}
                          class="neon-checkbox"
                        />
                        <span>
                          <span class="block text-sm font-semibold text-slate-50">
                            {material.name}
                          </span>
                          <span class="block text-xs text-emerald-200/60">
                            {material.unit} - {price_toman(material.price)}
                          </span>
                        </span>
                      </label>

                      <div
                        :if={available_materials(@materials_list, @product_items) == []}
                        class="neon-empty"
                      >
                        همه متریال ها به لیست محصول اضافه شده اند.
                      </div>
                    </div>

                    <button type="submit" class="neon-btn w-full">
                      افزودن متریال های انتخاب شده
                    </button>
                  </.form>
                </div>

                <div :if={@product_errors != []} class="neon-alert">
                  <%= for message <- @product_errors do %>
                    <p>{message}</p>
                  <% end %>
                </div>

                <div class="space-y-2">
                  <p class="text-sm font-semibold text-emerald-100">متریال های انتخاب شده</p>

                  <.form
                    :if={@product_items != []}
                    for={to_form(%{}, as: "quantities")}
                    id="item-quantities-form"
                    phx-change="item-quantities-change"
                    class="space-y-2"
                  >
                    <div :for={item <- @product_items} class="neon-subrow">
                      <div class="min-w-0">
                        <p class="text-sm font-semibold text-emerald-100">
                          {material_name(item.material_id, @materials_by_id)}
                        </p>

                        <p class="text-xs text-emerald-200/60">
                          واحد: {material_unit(item.material_id, @materials_by_id)}
                        </p>
                      </div>

                      <div class="flex w-full items-end gap-3 sm:w-auto">
                        <.input
                          type="number"
                          id={"item-quantity-#{item.material_id}"}
                          name={"items[#{item.material_id}][quantity]"}
                          value={item.quantity || ""}
                          label="مقدار"
                          class="neon-input min-w-28"
                          error_class="neon-input-error"
                          min="0.01"
                          step="0.01"
                        />

                        <button
                          type="button"
                          class="neon-link pb-3"
                          phx-click="item-remove"
                          phx-value-material_id={item.material_id}
                        >
                          حذف
                        </button>
                      </div>
                    </div>
                  </.form>

                  <div :if={@product_items == []} class="neon-empty">
                    هنوز متریالی برای این محصول انتخاب نشده است.
                  </div>
                </div>

                <button type="submit" form="product-form" class="neon-btn w-full">
                  {if @editing_product_id, do: "ذخیره تغییرات محصول", else: "ثبت محصول"}
                </button>
              </div>
            </section>
          </div>
        </div>

        <button
          :if={@active_tab == :materials and not @material_modal_open}
          type="button"
          id="fixed-add-material"
          class="neon-fixed-add"
          phx-click="material-new"
        >
          افزودن
        </button>

        <button
          :if={@active_tab == :products and not @product_modal_open}
          type="button"
          id="fixed-add-product"
          class="neon-fixed-add"
          phx-click="product-new"
        >
          افزودن
        </button>
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
    |> normalize_form_values()
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  defp normalize_form_values(%_struct{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :product_items, :items, :material, :product])
  end

  defp normalize_form_values(map), do: map

  defp available_materials(materials, items) do
    selected_ids = MapSet.new(items, & &1.material_id)
    Enum.reject(materials, &MapSet.member?(selected_ids, &1.id))
  end

  defp add_items(items, material_ids) do
    selected_ids = MapSet.new(items, & &1.material_id)

    new_items =
      material_ids
      |> Enum.reject(&MapSet.member?(selected_ids, &1))
      |> Enum.map(&%{material_id: &1, quantity: nil})

    items ++ new_items
  end

  defp material_name(material_id, materials_by_id) do
    case Map.get(materials_by_id, material_id) do
      nil -> "متریال حذف شده"
      material -> material.name
    end
  end

  defp material_unit(material_id, materials_by_id) do
    case Map.get(materials_by_id, material_id) do
      nil -> "-"
      material -> material.unit
    end
  end

  defp product_total(product, materials_by_id) do
    materials_total =
      Enum.reduce(product.items, 0, fn item, acc ->
        case Map.get(materials_by_id, item.material_id) do
          nil -> acc
          material -> acc + material.price * item.quantity
        end
      end)

    materials_total + product_profit(product)
  end

  defp product_profit(product), do: product.profit || 0

  defp price_toman(amount) when is_number(amount) do
    formatted =
      amount
      |> round()
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

  defp parse_quantity(nil), do: nil

  defp parse_quantity(value) when is_integer(value), do: value * 1.0

  defp parse_quantity(value) when is_float(value), do: value

  defp parse_quantity(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> nil
    end
  end

  defp parse_direction("up"), do: :up
  defp parse_direction("down"), do: :down
  defp parse_direction(_direction), do: nil

  defp refresh_materials(socket) do
    materials = Catalog.list_materials()
    visible_materials = filter_by_name(materials, socket.assigns[:material_search])

    socket
    |> assign(:materials_list, materials)
    |> assign(:materials_by_id, materials_by_id(materials))
    |> stream(:materials, visible_materials, reset: true)
  end

  defp refresh_products(socket) do
    products = Catalog.list_products()
    visible_products = filter_by_name(products, socket.assigns[:product_search])

    socket
    |> assign(:products_count, length(products))
    |> stream(:products, visible_products, reset: true)
  end

  defp filter_by_name(records, query) do
    query = query |> to_string() |> String.trim() |> String.downcase()

    if query == "" do
      records
    else
      Enum.filter(records, fn record ->
        record.name
        |> to_string()
        |> String.downcase()
        |> String.contains?(query)
      end)
    end
  end

  defp reset_material_form(socket) do
    socket
    |> assign(:editing_material_id, nil)
    |> assign(:material_modal_open, false)
    |> assign(:material_form, material_form(%{}))
    |> assign(:material_errors, %{})
  end

  defp reset_product_form(socket) do
    socket
    |> assign(:editing_product_id, nil)
    |> assign(:product_modal_open, false)
    |> assign(:product_items, [])
    |> assign(:product_form, product_form(%{profit: 0}))
    |> assign(:item_form, item_form(%{}))
    |> assign(:product_errors, [])
  end

  defp maybe_reset_deleted_product(socket, product_id) do
    if socket.assigns.editing_product_id == product_id do
      reset_product_form(socket)
    else
      socket
    end
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
