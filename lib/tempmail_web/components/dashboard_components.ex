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
      assign(assigns, :nav_groups, [
        %{
          label: "EMAIL",
          items: [
            %{key: :overview, href: "/dashboard", icon: "hero-squares-2x2", label: "Overview"},
            %{key: :mailboxes, href: "/dashboard/mailboxes", icon: "hero-inbox-stack", label: "Mailboxes"},
            %{key: :temp, href: "/dashboard/temp", icon: "hero-clock", label: "Temp Emails"}
          ]
        },
        %{
          label: "ORGANIZE",
          items: [
            %{key: :starred, href: "/dashboard/starred", icon: "hero-star", label: "Starred"},
            %{key: :archived, href: "/dashboard/archived", icon: "hero-archive-box", label: "Archived"}
          ]
        },
        %{
          label: "ACCOUNT",
          items: [
            %{key: :domains, href: "/dashboard/domains", icon: "hero-globe-alt", label: "My Domains"},
            %{key: :settings, href: "/dashboard/settings", icon: "hero-cog-6-tooth", label: "Settings"}
          ]
        }
      ])

    ~H"""
    <div class="min-h-screen bg-slate-50">
      <aside class="fixed left-0 top-16 z-40 hidden h-[calc(100vh-4rem)] w-60 border-r border-slate-200/80 bg-white md:block">
        <div class="flex h-full flex-col">
          <div class="p-3">
            <.link
              navigate={dashboard_path(@locale, "/dashboard/mailboxes?new=true")}
              class="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-indigo-600 to-purple-600 px-4 py-2.5 text-sm font-semibold text-white shadow-md shadow-indigo-500/25 transition-all hover:shadow-lg hover:shadow-indigo-500/30 hover:-translate-y-0.5"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> New Mailbox
            </.link>
          </div>

          <nav class="flex-1 overflow-auto px-3 pb-3">
            <div :for={group <- @nav_groups} class="mb-4">
              <p class="mb-1 px-3 text-[10px] font-bold tracking-widest text-slate-400">
                {group.label}
              </p>
              <.link
                :for={item <- group.items}
                navigate={dashboard_path(@locale, item.href)}
                class={[
                  "group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-all",
                  item.key == @active && "bg-indigo-50 text-indigo-700",
                  item.key != @active && "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <.icon
                  name={item.icon}
                  class={"h-[18px] w-[18px] flex-shrink-0 #{if item.key == @active, do: "text-indigo-600", else: "text-slate-400 group-hover:text-slate-600"}"}
                />
                <span>{item.label}</span>
                <span
                  :if={item.key == @active}
                  class="ml-auto h-1.5 w-1.5 rounded-full bg-indigo-600"
                />
              </.link>
            </div>
          </nav>

          <div class="border-t border-slate-100 p-3">
            <.link
              navigate={dashboard_path(@locale, "/dashboard/settings")}
              class="flex items-center gap-3 rounded-lg px-3 py-2 transition-colors hover:bg-slate-50"
            >
              <img
                :if={@current_user.image}
                src={@current_user.image}
                class="h-8 w-8 rounded-full ring-2 ring-white"
                alt=""
              />
              <div
                :if={!@current_user.image}
                class="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 text-xs font-bold text-white ring-2 ring-white"
              >
                {String.first(@current_user.name || @current_user.email || "?") |> String.upcase()}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-slate-900">
                  {@current_user.name || "User"}
                </p>
                <p class="truncate text-xs text-slate-500">{@current_user.email}</p>
              </div>
            </.link>
          </div>
        </div>
      </aside>

      <div class="border-b border-slate-200 bg-white px-4 py-2 md:hidden">
        <div class="flex gap-1.5 overflow-x-auto">
          <.link
            :for={item <- Enum.flat_map(@nav_groups, & &1.items)}
            navigate={dashboard_path(@locale, item.href)}
            class={[
              "inline-flex flex-shrink-0 items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold",
              item.key == @active && "bg-indigo-600 text-white",
              item.key != @active && "bg-slate-100 text-slate-600"
            ]}
          >
            <.icon name={item.icon} class="h-3.5 w-3.5" /> {item.label}
          </.link>
        </div>
      </div>

      <main class="transition-all duration-300 md:ml-60">
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
