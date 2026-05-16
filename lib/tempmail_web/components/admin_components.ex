defmodule TempmailWeb.AdminComponents do
  use Phoenix.Component

  import TempmailWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: TempmailWeb.Endpoint,
    router: TempmailWeb.Router,
    statics: TempmailWeb.static_paths()

  attr :active, :atom, required: true
  attr :locale, :string, default: "en"
  slot :inner_block, required: true

  def admin_shell(assigns) do
    assigns =
      assign(assigns, :nav_items, [
        %{key: :dashboard, href: "/admin", icon: "hero-squares-2x2", label: "Dashboard"},
        %{key: :domains, href: "/admin/domains", icon: "hero-globe-alt", label: "Domains"},
        %{key: :users, href: "/admin/users", icon: "hero-users", label: "Users"},
        %{key: :blog, href: "/admin/blog", icon: "hero-document-text", label: "Blog"},
        %{key: :analytics, href: "/admin/analytics", icon: "hero-chart-bar", label: "Analytics"},
        %{key: :settings, href: "/admin/settings", icon: "hero-cog-6-tooth", label: "Settings"}
      ])

    ~H"""
    <div class="min-h-screen bg-slate-50">
      <aside class="fixed left-0 top-16 z-40 hidden h-[calc(100vh-4rem)] w-64 border-r border-slate-200 bg-white md:block">
        <div class="flex h-full flex-col">
          <div class="flex items-center gap-2 border-b border-slate-200 p-4">
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-blue-600 to-purple-600">
              <.icon name="hero-envelope" class="h-4 w-4 text-white" />
            </div>
            <span class="font-semibold text-slate-950">Admin</span>
          </div>

          <nav class="flex-1 space-y-1 overflow-auto p-2">
            <.link
              :for={item <- @nav_items}
              navigate={admin_path(@locale, item.href)}
              class={[
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                item.key == @active && "bg-blue-600 text-white",
                item.key != @active && "text-slate-700 hover:bg-slate-100"
              ]}
            >
              <.icon name={item.icon} class="h-5 w-5 flex-shrink-0" />
              <span>{item.label}</span>
            </.link>
          </nav>
        </div>
      </aside>

      <div class="border-b border-slate-200 bg-white px-4 py-3 md:hidden">
        <div class="flex gap-2 overflow-x-auto">
          <.link
            :for={item <- @nav_items}
            navigate={admin_path(@locale, item.href)}
            class={[
              "inline-flex flex-shrink-0 items-center gap-2 rounded-xl px-3 py-2 text-sm font-semibold",
              item.key == @active && "bg-blue-600 text-white",
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

  defp admin_path("en", href), do: href
  defp admin_path(nil, href), do: href
  defp admin_path(locale, href), do: "/#{locale}#{href}"
end
