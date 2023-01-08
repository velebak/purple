defmodule PurpleWeb.FinanceLive.CategoryReport do
  use PurpleWeb, :live_view

  import PurpleWeb.FinanceLive.Helpers

  alias Purple.Finance
  alias Purple.Finance.PaymentMethod

  defp assign_data(socket) do
    assign(
      socket,
      :report,
      Finance.sum_transactions_by_category(%{user_id: socket.assigns.current_user.id})
    )
  end

  @impl Phoenix.LiveView
  def mount(_, _, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Categories")
      |> assign(:side_nav, side_nav())
      |> assign_data()
    }
  end

  @impl Phoenix.LiveView
  def handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1 class="mb-2"><%= @page_title %></h1>
    <.table rows={@report}>
      <:col :let={row} label="Total">
        <%= Finance.Transaction.format_cents(row.cents) %>
      </:col>
      <:col :let={row} label="Category">
        <%= Purple.titleize(row.category) %>
      </:col>
      <:col :let={row} label="Month">
        <%= Purple.titleize(row.month) %>
      </:col>
    </.table>
    """
  end
end
