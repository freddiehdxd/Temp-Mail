defmodule TempmailWeb.AdminLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Mail, Support}

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      users = Accounts.list_users()
      domains = Mail.list_domains()
      stats = Mail.recent_stats(14)
      sessions = Mail.list_recent_temp_email_sessions(5)

      {current_week, prev_week} = split_stats(stats)

      current_generated = Enum.reduce(current_week, 0, &(&1.generated + &2))
      current_received = Enum.reduce(current_week, 0, &(&1.received + &2))
      prev_generated = Enum.reduce(prev_week, 0, &(&1.generated + &2))
      prev_received = Enum.reduce(prev_week, 0, &(&1.received + &2))

      chart_data = build_chart_data(stats)

      {:ok,
       socket
       |> assign(:page_title, "Admin")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:users, users)
       |> assign(:domains, domains)
       |> assign(:stats, stats)
       |> assign(:sessions, sessions)
       |> assign(:total_generated, current_generated)
       |> assign(:total_received, current_received)
       |> assign(:generated_trend, trend_pct(current_generated, prev_generated))
       |> assign(:received_trend, trend_pct(current_received, prev_received))
       |> assign(:chart_data, chart_data)
       |> assign(
         :new_users_count,
         Enum.count(users, &(Date.diff(Date.utc_today(), DateTime.to_date(&1.inserted_at)) <= 7))
       )
       |> assign(:settings, Mail.list_settings())
       |> assign(:contact_messages, Support.list_recent_contact_messages(10))
       |> assign(:unread_contact_count, Support.count_unread_contact_messages())}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("ban", %{"id" => id}, socket) do
    socket.assigns.users
    |> Enum.find(&(&1.id == id))
    |> then(&(&1 && Accounts.ban_user(&1, "Banned by admin")))

    {:noreply, assign(socket, :users, Accounts.list_users())}
  end

  def handle_event("unban", %{"id" => id}, socket) do
    socket.assigns.users |> Enum.find(&(&1.id == id)) |> then(&(&1 && Accounts.unban_user(&1)))
    {:noreply, assign(socket, :users, Accounts.list_users())}
  end

  def handle_event("mark_message_read", %{"id" => id}, socket) do
    Support.mark_contact_message_read(id)

    {:noreply,
     socket
     |> assign(:contact_messages, Support.list_recent_contact_messages(10))
     |> assign(:unread_contact_count, Support.count_unread_contact_messages())}
  end

  def activity_chart_config(chart_data) do
    %{
      type: "line",
      data: %{
        labels: chart_data.labels,
        datasets: [
          %{
            label: "Generated",
            data: chart_data.generated,
            borderColor: "#3b82f6",
            borderWidth: 2,
            fill: true,
            tension: 0.4,
            pointRadius: 0,
            pointHoverRadius: 4,
            _gradient: %{from: "rgba(59,130,246,0.25)", to: "rgba(59,130,246,0)"}
          },
          %{
            label: "Received",
            data: chart_data.received,
            borderColor: "#8b5cf6",
            borderWidth: 2,
            fill: true,
            tension: 0.4,
            pointRadius: 0,
            pointHoverRadius: 4,
            _gradient: %{from: "rgba(139,92,246,0.25)", to: "rgba(139,92,246,0)"}
          }
        ]
      },
      options: %{
        responsive: true,
        maintainAspectRatio: false,
        interaction: %{mode: "index", intersect: false},
        plugins: %{
          legend: %{display: true, position: "top", labels: %{usePointStyle: true, padding: 20}},
          tooltip: %{
            backgroundColor: "rgba(15,23,42,0.9)",
            titleColor: "#f8fafc",
            bodyColor: "#cbd5e1",
            borderColor: "rgba(148,163,184,0.2)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8
          }
        },
        scales: %{
          x: %{grid: %{display: false}, ticks: %{color: "#94a3b8", font: %{size: 11}}},
          y: %{
            beginAtZero: true,
            grid: %{color: "rgba(148,163,184,0.1)"},
            ticks: %{color: "#94a3b8", font: %{size: 11}}
          }
        }
      }
    }
  end

  def bar_chart_config(chart_data) do
    %{
      type: "bar",
      data: %{
        labels: chart_data.labels,
        datasets: [
          %{
            label: "Generated",
            data: chart_data.generated,
            backgroundColor: "#3b82f6",
            borderRadius: 6,
            borderSkipped: false
          },
          %{
            label: "Received",
            data: chart_data.received,
            backgroundColor: "#8b5cf6",
            borderRadius: 6,
            borderSkipped: false
          }
        ]
      },
      options: %{
        responsive: true,
        maintainAspectRatio: false,
        plugins: %{
          legend: %{display: true, position: "top", labels: %{usePointStyle: true, padding: 20}},
          tooltip: %{
            backgroundColor: "rgba(15,23,42,0.9)",
            titleColor: "#f8fafc",
            bodyColor: "#cbd5e1",
            padding: 12,
            cornerRadius: 8
          }
        },
        scales: %{
          x: %{grid: %{display: false}, ticks: %{color: "#94a3b8", font: %{size: 11}}},
          y: %{
            beginAtZero: true,
            grid: %{color: "rgba(148,163,184,0.1)"},
            ticks: %{color: "#94a3b8", font: %{size: 11}}
          }
        }
      }
    }
  end

  defp split_stats(stats) do
    today = Date.utc_today()

    Enum.split_with(stats, fn stat ->
      Date.diff(today, stat.date) < 7
    end)
  end

  defp trend_pct(_current, 0), do: nil

  defp trend_pct(current, previous) do
    Float.round((current - previous) / previous * 100, 1)
  end

  defp build_chart_data(stats) do
    sorted = Enum.sort_by(stats, & &1.date, Date)

    %{
      labels: Enum.map(sorted, &Calendar.strftime(&1.date, "%b %d")),
      generated: Enum.map(sorted, & &1.generated),
      received: Enum.map(sorted, & &1.received)
    }
  end
end
