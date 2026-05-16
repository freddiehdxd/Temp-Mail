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
      <aside class="fixed left-0 top-14 z-40 hidden h-[calc(100vh-3.5rem)] w-64 border-r border-slate-200 bg-white md:block">
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

  # -- Shared dashboard components --

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :subtitle, :string, default: nil
  attr :trend, :any, default: nil
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :href, :string, required: true

  def stat_card(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="group relative overflow-hidden rounded-2xl border border-slate-200 bg-white p-6 shadow-sm transition-all hover:-translate-y-1 hover:shadow-lg"
    >
      <div class={"absolute right-0 top-0 h-32 w-32 translate-x-12 -translate-y-12 rounded-full bg-#{@color}-500/10 transition-transform group-hover:scale-125"}>
      </div>
      <div class="relative flex items-start justify-between">
        <div>
          <p class="text-sm font-medium text-slate-500">{@title}</p>
          <p class="mt-3 text-3xl font-bold text-slate-950">{@value}</p>
          <div class="mt-1 flex items-center gap-2">
            <.trend_badge :if={@trend} value={@trend} />
            <p class="text-xs text-slate-500">{@subtitle}</p>
          </div>
        </div>
        <div class={"rounded-xl bg-#{@color}-500/10 p-2.5"}>
          <.icon name={@icon} class={"h-5 w-5 text-#{@color}-500"} />
        </div>
      </div>
    </.link>
    """
  end

  attr :value, :float, required: true

  defp trend_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-semibold",
      @value >= 0 && "bg-emerald-100 text-emerald-700",
      @value < 0 && "bg-red-100 text-red-700"
    ]}>
      <.icon
        :if={@value >= 0}
        name="hero-arrow-trending-up-mini"
        class="h-3.5 w-3.5"
      />
      <.icon
        :if={@value < 0}
        name="hero-arrow-trending-down-mini"
        class="h-3.5 w-3.5"
      />
      {abs(@value)}%
    </span>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def chart_card(assigns) do
    ~H"""
    <section class="rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div class="border-b border-slate-200 p-5">
        <h2 class="text-lg font-bold text-slate-950">{@title}</h2>
        <p :if={@subtitle} class="text-sm text-slate-500">{@subtitle}</p>
      </div>
      <div class="p-5">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :session, :map, required: true

  def mailbox_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4">
      <div class="flex items-center gap-3">
        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-purple-500 text-sm font-semibold text-white">
          {String.first(@session.address || "?") |> String.upcase()}
        </div>
        <div>
          <p class="max-w-[220px] truncate text-sm font-medium text-slate-950">
            {@session.address}
          </p>
          <p class="text-xs text-slate-500">
            {(@session.user && (@session.user.name || @session.user.email)) || "Anonymous"}
          </p>
        </div>
      </div>
      <span class="text-xs text-slate-500">
        {Calendar.strftime(@session.inserted_at, "%b %d, %H:%M")}
      </span>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :status, :string, required: true

  def status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between border-b border-slate-100 py-3 last:border-0">
      <div class="flex items-center gap-3">
        <.icon name="hero-check-circle" class="h-5 w-5 text-emerald-500" />
        <span class="font-medium text-slate-950">{@name}</span>
      </div>
      <span class="rounded-full bg-emerald-100 px-2.5 py-1 text-sm text-emerald-700">
        {@status}
      </span>
    </div>
    """
  end

  defp admin_path("en", href), do: href
  defp admin_path(nil, href), do: href
  defp admin_path(locale, href), do: "/#{locale}#{href}"
end
