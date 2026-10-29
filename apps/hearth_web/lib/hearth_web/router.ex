defmodule HearthWeb.Router do
  use HearthWeb, :router

  @docs_cdns "https://cdn.jsdelivr.net https://cdn.redoc.ly"
  @swagger "https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.32.11"
  @swagger_bundle_url "#{@swagger}/swagger-ui-bundle.min.js"
  @swagger_preset_url "#{@swagger}/swagger-ui-standalone-preset.min.js"
  @swagger_css_url "#{@swagger}/swagger-ui.min.css"

  # The nonce is per request so the policy is set by its own plug
  # sobelow_skip ["Config.CSP"]
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HearthWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HearthWeb.Plugs.ContentSecurityPolicy
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Oaskit.Plugs.SpecProvider, spec: HearthWeb.OpenAPISpec
    plug HearthWeb.Plugs.ApiVersion
    plug HearthWeb.Plugs.RateLimit
    plug HearthWeb.Plugs.Authenticate
  end

  # Redoc and Swagger UI load from CDNs with inline scripts so this has its own policy
  # sobelow_skip ["Config.CSP"]
  pipeline :docs do
    plug :accepts, ["html"]
    plug HearthWeb.Plugs.ApiDocs

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'none'; script-src #{@docs_cdns} 'unsafe-inline'; " <>
          "style-src #{@docs_cdns} 'unsafe-inline' https://fonts.googleapis.com; " <>
          "font-src https://fonts.gstatic.com; img-src 'self' data: #{@docs_cdns}; " <>
          "worker-src blob:; connect-src 'self'; frame-src 'self'; frame-ancestors 'self'"
    }
  end

  pipeline :crawler do
    plug HearthWeb.Plugs.RateLimit
  end

  # Browser redirects so no JSON, version header or token
  pipeline :oauth do
    plug HearthWeb.Plugs.RateLimit
  end

  pipeline :api_docs do
    plug :accepts, ["json"]
    plug Oaskit.Plugs.SpecProvider, spec: HearthWeb.OpenAPISpec
    plug HearthWeb.Plugs.ApiDocs
  end

  scope "/", HearthWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", HearthWeb do
    pipe_through :crawler

    get "/robots.txt", SitemapController, :robots
    get "/sitemap.xml", SitemapController, :index
    get "/sitemaps/:file", SitemapController, :show

    get "/og/communities/:slug", ShareCardController, :community
    get "/og/posts/:id", ShareCardController, :post
    get "/og/events/:id", ShareCardController, :event
    get "/og/users/:username", ShareCardController, :user
  end

  scope "/api/auth/oauth", HearthWeb do
    pipe_through :oauth

    get "/:provider", OAuthController, :start
    get "/:provider/callback", OAuthController, :callback
  end

  scope "/api", HearthWeb do
    pipe_through :api

    get "/instance", InstanceController, :show
    patch "/instance", InstanceController, :update
    get "/instance/update", InstanceController, :update_status
    post "/instance/update/check", InstanceController, :check_update

    post "/auth/codes", AuthController, :request_code
    post "/auth/sessions", AuthController, :sign_in
    post "/auth/users", AuthController, :register
    post "/auth/refresh", AuthController, :refresh
    delete "/auth/session", AuthController, :sign_out
    get "/auth/me", AuthController, :me
    patch "/auth/me", AuthController, :update_me
    patch "/auth/me/settings", AuthController, :update_settings
    post "/auth/me/email", AuthController, :request_email_change
    post "/auth/me/email/confirm", AuthController, :confirm_email_change
    post "/auth/email/undo", AuthController, :undo_email_change
    get "/auth/me/invites", InviteController, :mine
    get "/usernames/:username", UsernameController, :show

    post "/uploads", UploadController, :create
    get "/uploads/:id/parts", UploadController, :parts
    post "/uploads/:id/part-urls", UploadController, :part_urls
    post "/uploads/:id/complete", UploadController, :complete

    get "/media/:id", MediaController, :show
    get "/link-preview", LinkPreviewController, :show
    delete "/media/:id", MediaController, :delete

    get "/community-templates", CommunityTemplateController, :index
    get "/community-slugs", CommunityController, :slug
    get "/communities", CommunityController, :index
    get "/public/communities", CommunityController, :public
    post "/communities", CommunityController, :create
    get "/communities/:id", CommunityController, :show
    patch "/communities/:id", CommunityController, :update
    post "/communities/:id/membership", CommunityController, :join
    delete "/communities/:id/membership", CommunityController, :leave
    post "/communities/:id/owner/code", CommunityController, :transfer_code
    put "/communities/:id/owner", CommunityController, :transfer

    get "/community-requests", CommunityRequestController, :index
    post "/community-requests/:id/decision", CommunityRequestController, :decide

    get "/communities/:community_id/rooms/archived", RoomController, :archived
    post "/communities/:community_id/rooms", RoomController, :create
    post "/communities/:community_id/roles", CommunityRoleController, :create
    put "/communities/:community_id/kinds", CommunityKindController, :update

    put "/communities/:community_id/members/:user_id/roles",
        CommunityRoleController,
        :member_roles

    patch "/roles/:id", CommunityRoleController, :update
    delete "/roles/:id", CommunityRoleController, :delete
    patch "/rooms/:id", RoomController, :update
    post "/rooms/:id/archive", RoomController, :archive
    post "/rooms/:id/restore", RoomController, :restore
    delete "/rooms/:id", RoomController, :delete

    get "/notifications", NotificationController, :index
    post "/push-subscriptions", PushSubscriptionController, :create
    delete "/push-subscriptions", PushSubscriptionController, :delete
    post "/notifications/read", NotificationController, :read_all
    post "/notifications/:id/read", NotificationController, :read

    get "/events", EventController, :index
    post "/communities/:community_id/events", EventController, :create
    patch "/events/:id", EventController, :update
    delete "/events/:id", EventController, :delete
    put "/events/:id/cancelled", EventController, :cancel
    post "/events/:id/interest", EventController, :interest

    get "/rooms/:id/voice-session", VoiceController, :live
    post "/rooms/:id/voice-sessions", VoiceController, :create
    post "/posts/:id/live", VoiceController, :discuss
    get "/voice-sessions/live", VoiceController, :live_index
    get "/voice-sessions/:id", VoiceController, :show
    post "/voice-sessions/:id/end", VoiceController, :end_session
    put "/voice-sessions/:id/hand", VoiceController, :hand
    put "/voice-sessions/:id/mute", VoiceController, :mute
    post "/voice-sessions/:id/participants/:user_id/invite", VoiceController, :invite
    post "/voice-sessions/:id/participants/:user_id/demote", VoiceController, :demote
    put "/voice-sessions/:id/participants/:user_id/server-mute", VoiceController, :server_mute
    delete "/voice-sessions/:id/participants/:user_id", VoiceController, :disconnect
    post "/voice-sessions/:id/share", VoiceController, :start_share
    delete "/voice-sessions/:id/share", VoiceController, :stop_share
    post "/voice-sessions/:id/recording", VoiceController, :start_recording
    delete "/voice-sessions/:id/recording", VoiceController, :stop_recording

    get "/rooms/:id/recordings", RecordingController, :room_index
    get "/events/:id/recordings", RecordingController, :event_index
    get "/posts/:id/recordings", RecordingController, :post_index
    get "/recordings/:id", RecordingController, :show
    patch "/recordings/:id", RecordingController, :update
    delete "/recordings/:id", RecordingController, :delete

    get "/voice-sessions/:id/transcript", TranscriptController, :show
    put "/transcript-segments/:id", TranscriptController, :update_segment

    get "/communities/:community_id/roles", CommunityRoleController, :index
    get "/communities/:community_id/members", CommunityMemberController, :index
    get "/people", PeopleController, :index
    get "/users", UserController, :index
    get "/users/:username", UserController, :show
    get "/users/:username/posts", UserController, :posts
    get "/users/:username/replies", UserController, :replies
    post "/emails/check", EmailCheckController, :create
    get "/communities/:community_id/invites", InviteController, :index
    post "/communities/:community_id/invites", InviteController, :create
    post "/communities/:community_id/invite-emails", InviteController, :email_create
    delete "/invite-emails/:id", InviteController, :email_delete
    post "/invite-emails/:id/decline", InviteController, :email_decline
    get "/invites/:code", InviteController, :show
    patch "/invites/:code", InviteController, :update
    post "/invites/:code/accept", InviteController, :accept
    delete "/invites/:code", InviteController, :delete

    get "/drafts", DraftController, :index
    put "/communities/:community_id/draft", DraftController, :update
    delete "/communities/:community_id/draft", DraftController, :delete
    get "/communities/:community_id/posts", PostController, :index
    get "/communities/:community_id/posts/pinned", PostController, :pinned
    post "/communities/:community_id/posts", PostController, :create
    get "/posts/:id", PostController, :show
    patch "/posts/:id", PostController, :update
    delete "/posts/:id", PostController, :delete
    put "/posts/:id/pin", PostController, :pin
    post "/posts/seen", PostController, :all_seen
    post "/communities/:community_id/posts/seen", PostController, :community_seen
    put "/posts/:id/lock", PostController, :lock
    put "/posts/:id/answer", PostController, :answer
    post "/posts/:id/helpful", PostController, :helpful
    post "/posts/:id/reactions", PostController, :react
    post "/posts/:id/seen", PostController, :seen
    put "/posts/:id/watch", PostController, :watch

    get "/posts/:post_id/replies", ReplyController, :index
    post "/posts/:post_id/replies", ReplyController, :create
    patch "/replies/:id", ReplyController, :update
    delete "/replies/:id", ReplyController, :delete
    post "/replies/:id/helpful", ReplyController, :helpful

    get "/rooms/:room_id/messages", MessageController, :room_index
    post "/rooms/:room_id/messages", MessageController, :room_create
    post "/rooms/:room_id/posts", PostController, :promote
    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    get "/conversations/:conversation_id/messages", MessageController, :conversation_index
    post "/conversations/:conversation_id/messages", MessageController, :conversation_create
    patch "/messages/:id", MessageController, :update
    delete "/messages/:id", MessageController, :delete
    post "/messages/:id/reactions", MessageController, :react
    post "/messages/:id/read", MessageController, :read
    put "/messages/:id/preview", MessageController, :preview
    get "/unread", UnreadController, :show

    post "/reports", ReportController, :create
    get "/moderation/counts", ModerationController, :counts
    get "/communities/:community_id/moderation/queue", ModerationController, :queue
    get "/communities/:community_id/moderation/log", ModerationController, :log
    put "/communities/:community_id/moderation", ModerationController, :community_level
    put "/rooms/:id/moderation", ModerationController, :room_level
    get "/instance/reports", ModerationController, :instance_queue
    get "/instance/screening", ModerationController, :screening_summary
    post "/moderation/items/:id/keep", ModerationController, :keep
    post "/moderation/items/:id/remove", ModerationController, :remove
    post "/moderation/items/:id/undo", ModerationController, :undo
    post "/moderation/items/:id/ban", ModerationController, :ban_author
    post "/moderation/remove", ModerationController, :remove_content
    post "/moderation/restore", ModerationController, :restore_content
    get "/communities/:community_id/bans", BanController, :index
    post "/communities/:community_id/bans", BanController, :create
    post "/bans/:id/lift", BanController, :lift
  end

  scope "/" do
    pipe_through :api_docs

    get "/openapi.json", Oaskit.SpecController, :show
  end

  scope "/" do
    pipe_through :docs

    get "/redoc", Oaskit.SpecController,
      redoc: "/openapi.json",
      redoc_config: %{
        "sanitize" => true,
        "schemaDefinitionsTagName" => "Schemas",
        "sortRequiredPropsFirst" => true
      }

    get "/docs", OpenApiSpex.Plug.SwaggerUI,
      path: "/openapi.json",
      tags_sorter: "alpha",
      operations_sorter: "alpha",
      swagger_ui_js_bundle_url: @swagger_bundle_url,
      swagger_ui_js_standalone_preset_url: @swagger_preset_url,
      swagger_ui_css_url: @swagger_css_url
  end

  if Application.compile_env(:hearth_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: HearthWeb.Telemetry,
        csp_nonce_assign_key: %{img: :csp_nonce, script: :csp_nonce, style: :csp_nonce}

      forward "/mailbox", Plug.Swoosh.MailboxPreview,
        csp_nonce_assign_key: %{script: :csp_nonce, style: :csp_nonce}
    end
  end
end
