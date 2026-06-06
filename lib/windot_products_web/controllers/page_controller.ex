defmodule WindotProductsWeb.PageController do
  use WindotProductsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
