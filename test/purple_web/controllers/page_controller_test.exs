defmodule PurpleWeb.PageControllerTest do
  use PurpleWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Purple"
  end
end
