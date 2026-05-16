defmodule TempmailWeb.AdminAnalyticsLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Mail}

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      days = parse_days(Map.get(params, "days", "30"))
      stats = Mail.recent_stats(days)

      {:ok,
       socket
       |> assign(:page_title, "Analytics")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:days, days)
       |> assign_stats(stats)}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("range", %{"days" => days}, socket) do
    days = parse_days(days)
    {:noreply, socket |> assign(:days, days) |> assign_stats(Mail.recent_stats(days))}
  end

  defp assign_stats(socket, stats) do
    total_generated = Enum.reduce(stats, 0, &(&1.generated + &2))
    total_received = Enum.reduce(stats, 0, &(&1.received + &2))
    avg_daily = if length(stats) > 0, do: round(total_generated / length(stats)), else: 0

    conversion =
      if total_generated > 0, do: round(total_received / total_generated * 100), else: 0

    peak = Enum.max_by(stats, &(&1.generated + &1.received), fn -> nil end)

    socket
    |> assign(:stats, stats)
    |> assign(:total_generated, total_generated)
    |> assign(:total_received, total_received)
    |> assign(:avg_daily, avg_daily)
    |> assign(:conversion, conversion)
    |> assign(:peak, peak)
  end

  defp parse_days(value) when value in ["7", "30", "90"], do: String.to_integer(value)
  defp parse_days(value) when value in [7, 30, 90], do: value
  defp parse_days(_), do: 30
end
