defmodule TempmailWeb.DashboardComponents do
  use Phoenix.Component

  import TempmailWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: TempmailWeb.Endpoint,
    router: TempmailWeb.Router,
    statics: TempmailWeb.static_paths()

  attr :current_user, :map, required: true
  attr :active, :atom, required: true
  attr :locale, :string, default: "en"
  slot :inner_block, required: true

  def dashboard_shell(assigns) do
    assigns =
      assign(assigns, :nav_items, [
        %{key: :overview, href: "/dashboard", icon: "hero-squares-2x2", label: "Overview"},
        %{
          key: :mailboxes,
          href: "/dashboard/mailboxes",
          icon: "hero-inbox",
          label: "My Mailboxes"
        },
        %{key: :domains, href: "/dashboard/domains", icon: "hero-globe-alt", label: "Domains"},
        %{key: :temp, href: "/dashboard/temp", icon: "hero-clock", label: "Temp Emails"},
        %{key: :starred, href: "/dashboard/starred", icon: "hero-star", label: "Starred"},
        %{
          key: :archived,
          href: "/dashboard/archived",
          icon: "hero-archive-box",
          label: "Archived"
        },
        %{
          key: :settings,
          href: "/dashboard/settings",
          icon: "hero-cog-6-tooth",
          label: "Settings"
        }
      ])

    ~H"""
    <div class="min-h-screen bg-slate-50">
      <aside class="fixed left-0 top-16 z-40 hidden h-[calc(100vh-4rem)] w-64 border-r border-slate-200 bg-white md:block">
        <div class="flex h-full flex-col">
          <div class="flex items-center gap-2 border-b border-slate-200 p-4">
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-indigo-600 to-purple-600">
              <.icon name="hero-envelope" class="h-4 w-4 text-white" />
            </div>
            <span class="font-semibold text-slate-950">Dashboard</span>
          </div>

          <div class="border-b border-slate-200 p-3">
            <.link
              navigate={dashboard_path(@locale, "/dashboard/mailboxes?new=true")}
              class="tm-btn-gradient w-full gap-2"
            >
              <.icon name="hero-plus" class="h-5 w-5" /> New Mailbox
            </.link>
          </div>

          <nav class="flex-1 space-y-1 overflow-auto p-2">
            <.link
              :for={item <- @nav_items}
              navigate={dashboard_path(@locale, item.href)}
              class={[
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                item.key == @active && "bg-indigo-600 text-white",
                item.key != @active && "text-slate-700 hover:bg-slate-100"
              ]}
            >
              <.icon name={item.icon} class="h-5 w-5 flex-shrink-0" />
              <span>{item.label}</span>
            </.link>
          </nav>

          <div class="border-t border-slate-200 p-4">
            <div class="flex items-center gap-3">
              <img
                :if={@current_user.image}
                src={@current_user.image}
                class="h-8 w-8 rounded-full"
                alt=""
              />
              <div
                :if={!@current_user.image}
                class="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 text-sm font-semibold text-white"
              >
                {String.first(@current_user.name || @current_user.email || "?") |> String.upcase()}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-medium text-slate-950">
                  {@current_user.name || "User"}
                </p>
                <p class="truncate text-xs text-slate-500">{@current_user.email}</p>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <div class="border-b border-slate-200 bg-white px-4 py-3 md:hidden">
        <div class="flex gap-2 overflow-x-auto">
          <.link
            :for={item <- @nav_items}
            navigate={dashboard_path(@locale, item.href)}
            class={[
              "inline-flex flex-shrink-0 items-center gap-2 rounded-xl px-3 py-2 text-sm font-semibold",
              item.key == @active && "bg-indigo-600 text-white",
              item.key != @active && "bg-slate-100 text-slate-700"
            ]}
          >
            <.icon name={item.icon} class="h-4 w-4" /> {item.label}
          </.link>
        </div>
      </div>

      <main class="transition-all duration-300 md:ml-64">
        <div class="p-6 md:p-8">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>
    """
  end

  defp dashboard_path("en", href), do: href
  defp dashboard_path(nil, href), do: href
  defp dashboard_path(locale, href), do: "/#{locale}#{href}"
end
