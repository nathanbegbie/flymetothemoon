defmodule FlymetothemoonWeb.PageController do
  use FlymetothemoonWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
