defmodule PurpleWeb.Router do
  use PurpleWeb, :router
  import Phoenix.LiveDashboard.Router
  import PurpleWeb.UserAuth

  def require_api_secret(conn, _opts) do
    api_secret = Application.fetch_env!(:purple, :api_secret)

    case get_req_header(conn, "x-purple-api-secret") do
      [^api_secret] ->
        conn

      _ ->
        conn
        |> send_resp(403, "API secret is required")
        |> halt()
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PurpleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :require_api_secret
  end

  ## Live Dashboard
  scope "/" do
    pipe_through [:browser, :require_authenticated_user]

    live_dashboard "/dashboard", metrics: PurpleWeb.Telemetry
  end

  scope "/api", PurpleWeb do
    pipe_through [:api]

    # post "/weather_snapshots", WeatherSnapshotController, :create
    post "/weather_snapshots/broadcast", WeatherSnapshotController, :broadcast
  end

  ## Authentication routes
  scope "/", PurpleWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{PurpleWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  ## Protected dead routes
  scope "/", PurpleWeb do
    pipe_through [:browser, :require_authenticated_user]
    get "/files/:id", FileController, :show
    get "/files/:id/thumbnail", FileController, :show_thumbnail
    get "/files/:id/download", FileController, :download
    get "/files/:id/open/:filename", FileController, :show
  end

  ## Unprotected live routes
  scope "/", PurpleWeb do
    pipe_through [:browser]

    live_session :fetch_current_user, on_mount: [{PurpleWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :show
    end
  end

  ## Protected live routes
  scope "/", PurpleWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PurpleWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit

      live "/feed", FeedLive.Index, :index

      live "/finance", FinanceLive.Index, :index
      live "/finance/transactions/create", FinanceLive.CreateTransaction, :create
      live "/finance/transactions/:id", FinanceLive.ShowTransaction, :show
      live "/finance/transactions/:id/edit", FinanceLive.ShowTransaction, :edit
      live "/finance/transactions/:id/files/:file_id", FinanceLive.ShowTransactionFile, :index
      live "/finance/transactions/:id/files/:file_id/edit", FinanceLive.ShowTransactionFile, :edit
      live "/finance/merchants", FinanceLive.MerchantIndex, :index
      live "/finance/merchants/:id", FinanceLive.ShowMerchant, :show
      live "/finance/merchants/:id/edit", FinanceLive.ShowMerchant, :edit
      live "/finance/payment_methods", FinanceLive.PaymentMethodIndex, :index
      live "/finance/categories", FinanceLive.CategoryReport, :index
      live "/finance/shared_budgets", FinanceLive.SharedBudgetIndex, :index
      live "/finance/shared_budgets/:id", FinanceLive.ShowSharedBudget, :show

      live "/finance/shared_budgets/:id/adjustments/new",
           FinanceLive.ShowSharedBudget,
           :new_adjustment

      live "/finance/shared_budgets/:id/adjustments/:adjustment_id",
           FinanceLive.ShowSharedBudget,
           :show_adjustment

      live "/finance/shared_budgets/:id/adjustments/:adjustment_id/edit",
           FinanceLive.ShowSharedBudget,
           :edit_adjustment

      live "/runs", RunLive.Index, :index
      live "/runs/create", RunLive.Index, :create
      live "/runs/edit/:id", RunLive.Index, :edit
      live "/runs/:id", RunLive.Show, :show
      live "/runs/:id/edit", RunLive.Show, :edit

      live "/board", BoardLive.Index, :index
      live "/board/settings", BoardLive.BoardSettings, :index
      live "/board/settings/new", BoardLive.BoardSettings, :create
      live "/board/settings/:id", BoardLive.BoardSettings, :edit
      live "/board/:user_board_id", BoardLive.Board, :show
      live "/board/item/create", BoardLive.CreateItem, :create
      live "/board/item/:id", BoardLive.ShowItem, :show
      live "/board/item/:id/edit", BoardLive.ShowItem, :edit_item
      live "/board/item/:id/entry/:entry_id", BoardLive.ShowItem, :edit_entry
      live "/board/item/:id/files/:file_id", BoardLive.ShowItemFile, :show
      live "/board/item/:id/files/:file_id/edit", BoardLive.ShowItemFile, :edit
      live "/board/item/:id/files", BoardLive.ItemGallery, :index
    end
  end

  ## Unprotected routes
  scope "/", PurpleWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end
end
