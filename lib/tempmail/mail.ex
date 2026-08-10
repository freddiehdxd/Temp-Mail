defmodule Tempmail.Mail do
  @moduledoc """
  Mail, domain, Redis inbox, and stats context.

  Temporary inboxes live in Redis and notify LiveViews over PubSub when a
  webhook stores a new message. Persistent mailboxes and reporting data live in
  Postgres through Ecto.
  """

  import Ecto.Query, warn: false
  alias Tempmail.Repo

  alias Tempmail.Mail.{
    AuditLog,
    Domain,
    EmailStat,
    Setting,
    TempEmailSession,
    UserDomain,
    UserEmail,
    UserMailbox
  }

  alias Tempmail.Integrations.Mailcow

  @reserved_prefixes ~w(admin administrator abuse postmaster hostmaster webmaster support contact info sales noreply no-reply security root mail email)

  def default_ttl, do: Application.get_env(:tempmail, :default_email_ttl, 600)

  def list_domains do
    Domain |> order_by([d], desc: d.is_default, asc: d.domain) |> Repo.all()
  end

  def list_active_domains do
    Domain
    |> where([d], d.is_active == true)
    |> order_by([d], desc: d.is_default, asc: d.domain)
    |> Repo.all()
  end

  def get_domain!(id), do: Repo.get!(Domain, id)

  def create_domain(attrs, audit_user \\ nil) do
    result =
      %Domain{}
      |> Domain.changeset(attrs)
      |> Repo.insert()

    with {:ok, domain} <- result, %{} <- audit_user do
      create_audit_log(audit_user, "domain.create", domain.domain)
    end

    result
  end

  def update_domain(%Domain{} = domain, attrs) do
    domain
    |> Domain.changeset(attrs)
    |> Repo.update()
  end

  def delete_domain(%Domain{} = domain, audit_user \\ nil) do
    result = Repo.delete(domain)

    with {:ok, _} <- result, %{} <- audit_user do
      create_audit_log(audit_user, "domain.delete", domain.domain)
    end

    result
  end

  def set_default_domain(%Domain{} = domain) do
    Repo.transaction(fn ->
      Repo.update_all(Domain, set: [is_default: false])
      update_domain(domain, %{is_default: true, is_active: true})
    end)
  end

  def choose_domain(nil), do: choose_domain("")

  def choose_domain("") do
    case list_active_domains() do
      [] -> Application.get_env(:tempmail, :default_domain, "tempmail.com")
      domains -> Enum.random(domains).domain
    end
  end

  def choose_domain(domain), do: String.downcase(domain)

  def create_temp_email(attrs \\ %{}) do
    domain = choose_domain(Map.get(attrs, "domain") || Map.get(attrs, :domain))
    id = unique_prefix()
    address = "#{id}@#{domain}"
    now = System.system_time(:millisecond)
    ttl = default_ttl()

    temp_email = %{
      id: id,
      address: address,
      domain: domain,
      createdAt: now,
      expiresAt: now + ttl * 1000,
      ttl: ttl
    }

    with {:ok, encoded} <- Jason.encode(temp_email),
         {:ok, "OK"} <- redis(["SETEX", temp_key(address), ttl, encoded]),
         {:ok, _} <- redis(["DEL", inbox_key(address)]),
         {:ok, _} <- redis(["EXPIRE", inbox_key(address), ttl]) do
      increment_stat(:generated)
      {:ok, temp_email}
    else
      error -> error
    end
  end

  def get_temp_email(address) when is_binary(address) do
    with {:ok, json} when is_binary(json) <- redis(["GET", temp_key(address)]),
         {:ok, temp_email} <- Jason.decode(json),
         {:ok, ttl} <- redis(["TTL", temp_key(address)]) do
      {:ok, Map.put(temp_email, "ttl", ttl)}
    else
      _ -> {:error, :not_found}
    end
  end

  def get_temp_email(_), do: {:error, :not_found}

  def refresh_temp_email(address, seconds \\ default_ttl()) do
    with {:ok, temp_email} <- get_temp_email(address) do
      now = System.system_time(:millisecond)

      updated =
        temp_email
        |> Map.put("expiresAt", now + seconds * 1000)
        |> Map.put("ttl", seconds)

      {:ok, encoded} = Jason.encode(updated)
      redis(["SETEX", temp_key(address), seconds, encoded])
      redis(["EXPIRE", inbox_key(address), seconds])
      {:ok, updated}
    end
  end

  def extend_temp_email(address, duration, current_user \\ nil) do
    seconds =
      case duration do
        "hour" -> 60 * 60
        "day" -> 24 * 60 * 60
        "week" -> 7 * 24 * 60 * 60
        "unlimited" -> 30 * 24 * 60 * 60
        n when is_integer(n) -> n
        _ -> default_ttl()
      end

    seconds =
      if is_nil(current_user) and seconds > 24 * 60 * 60 do
        24 * 60 * 60
      else
        seconds
      end

    with {:ok, temp_email} <- refresh_temp_email(address, seconds) do
      track_temp_session(current_user, temp_email, false)
      {:ok, temp_email}
    end
  end

  def get_inbox(address) do
    case redis(["LRANGE", inbox_key(address), "0", "-1"]) do
      {:ok, items} ->
        {:ok, Enum.map(items, &decode_message!/1)}

      error ->
        error
    end
  end

  def add_email_to_inbox(address, attrs) do
    with {:ok, _temp_email} <- get_temp_email(address) do
      message = normalize_message(address, attrs)
      {:ok, encoded} = Jason.encode(message)
      {:ok, _} = redis(["LPUSH", inbox_key(address), encoded])
      redis(["LTRIM", inbox_key(address), "0", "99"])

      ttl =
        case redis(["TTL", temp_key(address)]) do
          {:ok, ttl} when ttl > 0 -> ttl
          _ -> default_ttl()
        end

      redis(["EXPIRE", inbox_key(address), ttl])
      increment_stat(:received)
      Phoenix.PubSub.broadcast(Tempmail.PubSub, inbox_topic(address), {:inbox_email, message})
      {:ok, message}
    end
  end

  def mark_temp_email_read(address, email_id) do
    update_temp_inbox(address, fn messages ->
      Enum.map(messages, fn
        %{"id" => ^email_id} = message -> Map.put(message, "read", true)
        message -> message
      end)
    end)
  end

  def delete_temp_email(address, email_id) do
    update_temp_inbox(address, fn messages ->
      Enum.reject(messages, &(&1["id"] == email_id))
    end)
  end

  def route_incoming_email(attrs) do
    recipient = normalize_recipient(Map.get(attrs, "to") || Map.get(attrs, :to))

    case Repo.get_by(UserMailbox, address: recipient) do
      %UserMailbox{} = mailbox ->
        create_user_email(mailbox, normalize_persistent_email(attrs))

      nil ->
        add_email_to_inbox(recipient, attrs)
    end
  end

  def list_user_mailboxes(user) do
    UserMailbox
    |> where([m], m.user_id == ^user.id)
    |> order_by([m], desc: m.is_primary, asc: m.address)
    |> preload(:emails)
    |> Repo.all()
  end

  def get_user_mailbox!(user, id) do
    UserMailbox
    |> where([m], m.user_id == ^user.id and m.id == ^id)
    |> preload(:emails)
    |> Repo.one!()
  end

  def get_user_mailbox(user, id) do
    UserMailbox
    |> where([m], m.user_id == ^user.id and m.id == ^id)
    |> preload(emails: ^from(e in UserEmail, order_by: [desc: e.received_at]))
    |> Repo.one()
  end

  def create_user_mailbox(user, attrs) do
    address =
      case Map.get(attrs, "address") do
        address when is_binary(address) and address != "" ->
          address

        _ ->
          prefix = Map.get(attrs, "prefix") || unique_prefix()
          domain = Map.get(attrs, "domain") || choose_domain("")
          "#{prefix}@#{domain}"
      end
      |> String.trim()
      |> String.downcase()

    [prefix, domain] = String.split(address, "@", parts: 2)
    count = Repo.aggregate(from(m in UserMailbox, where: m.user_id == ^user.id), :count)

    with :ok <- ensure_mailbox_domain_allowed(user, domain),
         :ok <- ensure_mailbox_prefix_allowed(user, prefix, domain) do
      %UserMailbox{}
      |> UserMailbox.changeset(%{
        user_id: user.id,
        address: address,
        prefix: prefix,
        domain: domain,
        name: Map.get(attrs, "name"),
        is_primary: count == 0
      })
      |> Repo.insert()
    end
  end

  def promote_temp_email(user, address) do
    with {:ok, _temp_email} <- get_temp_email(address),
         false <- reserved_address?(address),
         {:ok, inbox} <- get_inbox(address),
         {:ok, mailbox} <- create_user_mailbox(user, %{"address" => address}) do
      Enum.each(inbox, fn message ->
        create_user_email(mailbox, normalize_persistent_email(message))
      end)

      redis(["DEL", temp_key(address)])
      redis(["DEL", inbox_key(address)])

      track_temp_session(
        user,
        %{"address" => address, "domain" => mailbox.domain, "expiresAt" => year_from_now_ms()},
        true
      )

      {:ok, mailbox}
    else
      true -> {:error, :reserved_prefix}
      error -> error
    end
  end

  def list_user_emails(user, limit \\ 25)

  def list_user_emails(user, opts) when is_list(opts) do
    mailbox_ids = from(m in UserMailbox, where: m.user_id == ^user.id, select: m.id)

    UserEmail
    |> where([e], e.mailbox_id in subquery(mailbox_ids))
    |> maybe_filter_mailbox(opts[:mailbox_id])
    |> maybe_filter_starred(opts[:starred])
    |> maybe_filter_archived(opts[:archived])
    |> order_by([e], desc: e.received_at)
    |> maybe_limit(opts[:limit])
    |> preload(:mailbox)
    |> Repo.all()
  end

  def list_user_emails(user, limit) do
    mailbox_ids = from(m in UserMailbox, where: m.user_id == ^user.id, select: m.id)

    UserEmail
    |> where([e], e.mailbox_id in subquery(mailbox_ids))
    |> order_by([e], desc: e.received_at)
    |> limit(^limit)
    |> preload(:mailbox)
    |> Repo.all()
  end

  def list_temp_email_sessions(user) do
    TempEmailSession
    |> where([s], s.user_id == ^user.id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def list_recent_temp_email_sessions(limit \\ 5) do
    TempEmailSession
    |> order_by([s], desc: s.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  def update_user_email(user, id, attrs) do
    mailbox_ids = from(m in UserMailbox, where: m.user_id == ^user.id, select: m.id)

    UserEmail
    |> where([e], e.id == ^id and e.mailbox_id in subquery(mailbox_ids))
    |> Repo.one()
    |> case do
      %UserEmail{} = email -> email |> UserEmail.changeset(attrs) |> Repo.update()
      nil -> {:error, :not_found}
    end
  end

  def delete_user_email(user, id) do
    mailbox_ids = from(m in UserMailbox, where: m.user_id == ^user.id, select: m.id)

    UserEmail
    |> where([e], e.id == ^id and e.mailbox_id in subquery(mailbox_ids))
    |> Repo.one()
    |> case do
      %UserEmail{} = email -> Repo.delete(email)
      nil -> {:error, :not_found}
    end
  end

  def get_user_email(user, id) do
    mailbox_ids = from(m in UserMailbox, where: m.user_id == ^user.id, select: m.id)

    UserEmail
    |> where([e], e.id == ^id and e.mailbox_id in subquery(mailbox_ids))
    |> preload(:mailbox)
    |> Repo.one()
  end

  def delete_user_mailbox(user, id) do
    UserMailbox
    |> where([m], m.user_id == ^user.id and m.id == ^id)
    |> Repo.one()
    |> case do
      %UserMailbox{} = mailbox -> Repo.delete(mailbox)
      nil -> {:error, :not_found}
    end
  end

  def create_user_email(%UserMailbox{} = mailbox, attrs) do
    attrs = Map.put(attrs, :mailbox_id, mailbox.id)

    %UserEmail{}
    |> UserEmail.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, email} ->
        increment_stat(:received)

        Phoenix.PubSub.broadcast(
          Tempmail.PubSub,
          inbox_topic(mailbox.address),
          {:persistent_email, email}
        )

      _ ->
        :ok
    end)
  end

  def list_user_domains(user) do
    UserDomain |> where([d], d.user_id == ^user.id) |> order_by([d], asc: d.domain) |> Repo.all()
  end

  def list_available_mailbox_domains(user) do
    system_domains =
      Domain
      |> where([d], d.is_active == true)
      |> order_by([d], desc: d.is_default, asc: d.domain)
      |> Repo.all()

    user_domains =
      UserDomain
      |> where(
        [d],
        d.user_id == ^user.id and d.is_active == true and d.is_verified == true
      )
      |> order_by([d], asc: d.domain)
      |> Repo.all()

    system_domains ++ user_domains
  end

  def create_user_domain(user, attrs) do
    domain = attrs |> Map.get("domain", "") |> String.trim() |> String.downcase()

    cond do
      Repo.exists?(from(d in Domain, where: d.domain == ^domain)) ->
        {:error, :system_domain}

      Repo.exists?(from(d in UserDomain, where: d.domain == ^domain)) ->
        {:error, :domain_claimed}

      Repo.aggregate(from(d in UserDomain, where: d.user_id == ^user.id), :count) >=
          Application.get_env(:tempmail, :max_user_domains, 5) ->
        {:error, :domain_limit}

      true ->
        attrs
        |> Map.put("user_id", user.id)
        |> Map.put("domain", domain)
        |> then(&(%UserDomain{} |> UserDomain.changeset(&1) |> Repo.insert()))
    end
  end

  def delete_user_domain(user, id) do
    with %UserDomain{} = domain <-
           UserDomain |> where([d], d.user_id == ^user.id and d.id == ^id) |> Repo.one(),
         0 <-
           Repo.aggregate(
             from(m in UserMailbox, where: m.user_id == ^user.id and m.domain == ^domain.domain),
             :count
           ) do
      if domain.is_verified && Mailcow.configured?(), do: Mailcow.delete_domain(domain.domain)
      Repo.delete(domain)
    else
      nil -> {:error, :not_found}
      mailbox_count when is_integer(mailbox_count) -> {:error, {:domain_in_use, mailbox_count}}
    end
  end

  def verify_user_domain(%UserDomain{} = domain) do
    results = verify_user_domain_dns(domain)
    was_verified? = domain.is_verified

    update_attrs = %{
      mx_verified: results.mx,
      spf_verified: results.spf,
      is_verified: results.ownership and results.mx,
      verified_at:
        if(results.ownership and results.mx,
          do: domain.verified_at || DateTime.utc_now() |> DateTime.truncate(:second)
        )
    }

    with {:ok, updated_domain} <- domain |> UserDomain.changeset(update_attrs) |> Repo.update() do
      if updated_domain.is_verified && !was_verified? && Mailcow.configured?() do
        setup_verified_domain(updated_domain.domain)
      end

      {:ok, updated_domain, results}
    end
  end

  def verify_user_domain_dns(%UserDomain{} = domain) do
    ownership_result = dns_has_ownership_txt?(domain.domain, domain.verification_token)
    mx_result = dns_has_required_mx?(domain.domain)
    spf = dns_has_spf?(domain.domain)

    errors =
      []
      |> maybe_dns_error(
        ownership_result,
        "TXT record \"_tempmail-verify.#{domain.domain}\" not found or value does not match. Expected: #{domain.verification_token}"
      )
      |> maybe_dns_error(mx_result, "MX record must point to #{mail_server_hostname()}.")

    %{
      ownership: ownership_result == true,
      mx: mx_result == true,
      spf: spf == true,
      errors: errors
    }
  end

  def list_settings do
    Setting |> order_by([s], asc: s.key) |> Repo.all()
  end

  def upsert_setting(key, value, type \\ "string") do
    %Setting{}
    |> Setting.changeset(%{key: key, value: value, type: type})
    |> Repo.insert(
      on_conflict: [
        set: [
          value: value,
          type: type,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        ]
      ],
      conflict_target: :key
    )
  end

  def create_audit_log(user, action, target \\ nil, details \\ nil, ip \\ nil) do
    %AuditLog{}
    |> AuditLog.changeset(%{
      user_id: user && user.id,
      action: action,
      target: target,
      details: details,
      ip_address: ip
    })
    |> Repo.insert()
  end

  def list_audit_logs(limit \\ 50) do
    AuditLog
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  All-time aggregate counters, used for the public stats shown on the site.
  """
  def total_stats do
    EmailStat
    |> select([s], %{
      generated: coalesce(sum(s.generated), 0),
      received: coalesce(sum(s.received), 0)
    })
    |> Repo.one()
  end

  def recent_stats(days \\ 14) do
    start_date = Date.utc_today() |> Date.add(-days + 1)

    EmailStat
    |> where([s], s.date >= ^start_date)
    |> order_by([s], asc: s.date)
    |> Repo.all()
  end

  def inbox_topic(address), do: "inbox:#{String.downcase(address)}"

  def reserved_address?(address) do
    address
    |> String.split("@")
    |> List.first()
    |> reserved_prefix?()
  end

  def reserved_prefix?(prefix), do: String.downcase(prefix || "") in @reserved_prefixes

  defp unique_prefix do
    prefix =
      :crypto.strong_rand_bytes(9)
      |> Base.url_encode64(padding: false)
      |> String.replace(~r/[^a-zA-Z0-9]/, "")
      |> String.downcase()
      |> String.slice(0, 10)

    if byte_size(prefix) < 8 or reserved_prefix?(prefix), do: unique_prefix(), else: prefix
  end

  defp temp_key(address), do: "temp:#{String.downcase(address)}"
  defp inbox_key(address), do: "inbox:#{String.downcase(address)}"

  defp redis(command), do: Redix.command(Tempmail.Redis, command)

  defp decode_message!(json) do
    {:ok, message} = Jason.decode(json)
    message
  end

  defp normalize_message(address, attrs) do
    %{
      "id" => Map.get(attrs, "id") || Map.get(attrs, :id) || Ecto.UUID.generate(),
      "from" => Map.get(attrs, "from") || Map.get(attrs, :from) || "unknown@unknown.com",
      "fromName" => Map.get(attrs, "fromName") || Map.get(attrs, :from_name),
      "to" => address,
      "subject" => Map.get(attrs, "subject") || Map.get(attrs, :subject) || "(No Subject)",
      "text" => Map.get(attrs, "text") || Map.get(attrs, :text) || "",
      "html" => Map.get(attrs, "html") || Map.get(attrs, :html) || "",
      "receivedAt" => Map.get(attrs, "receivedAt") || System.system_time(:millisecond),
      "read" => Map.get(attrs, "read") || false,
      "attachments" =>
        normalize_attachments(Map.get(attrs, "attachments") || Map.get(attrs, :attachments))
    }
  end

  defp normalize_persistent_email(attrs) do
    %{
      from: Map.get(attrs, "from") || Map.get(attrs, :from) || "unknown@unknown.com",
      from_name:
        Map.get(attrs, "fromName") || Map.get(attrs, "from_name") || Map.get(attrs, :from_name),
      subject: Map.get(attrs, "subject") || Map.get(attrs, :subject) || "(No Subject)",
      text: Map.get(attrs, "text") || Map.get(attrs, :text) || "",
      html: Map.get(attrs, "html") || Map.get(attrs, :html) || "",
      received_at: to_datetime(Map.get(attrs, "receivedAt") || Map.get(attrs, :received_at)),
      read: Map.get(attrs, "read") || Map.get(attrs, :read) || false,
      attachments:
        normalize_attachments(Map.get(attrs, "attachments") || Map.get(attrs, :attachments))
    }
  end

  defp normalize_attachments(nil), do: nil
  defp normalize_attachments(attachments) when is_list(attachments), do: attachments
  defp normalize_attachments(_), do: nil

  defp maybe_filter_mailbox(query, nil), do: query
  defp maybe_filter_mailbox(query, mailbox_id), do: where(query, [e], e.mailbox_id == ^mailbox_id)

  defp maybe_filter_starred(query, nil), do: query
  defp maybe_filter_starred(query, value), do: where(query, [e], e.starred == ^value)

  defp maybe_filter_archived(query, nil), do: query
  defp maybe_filter_archived(query, value), do: where(query, [e], e.archived == ^value)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp normalize_recipient([first | _]), do: normalize_recipient(first)
  defp normalize_recipient(value) when is_binary(value), do: String.downcase(value)
  defp normalize_recipient(_), do: ""

  defp to_datetime(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp to_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  defp to_datetime(ms) when is_integer(ms),
    do: DateTime.from_unix!(ms, :millisecond) |> DateTime.truncate(:second)

  defp to_datetime(_), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp update_temp_inbox(address, fun) do
    with {:ok, messages} <- get_inbox(address),
         messages <- fun.(messages),
         {:ok, _} <- redis(["DEL", inbox_key(address)]) do
      Enum.reverse(messages)
      |> Enum.each(fn message ->
        {:ok, encoded} = Jason.encode(message)
        redis(["LPUSH", inbox_key(address), encoded])
      end)

      case redis(["TTL", temp_key(address)]) do
        {:ok, ttl} when ttl > 0 -> redis(["EXPIRE", inbox_key(address), ttl])
        _ -> :ok
      end

      Phoenix.PubSub.broadcast(Tempmail.PubSub, inbox_topic(address), {:inbox_updated, messages})
      {:ok, messages}
    end
  end

  defp track_temp_session(nil, _temp_email, _permanent), do: :ok

  defp track_temp_session(user, temp_email, permanent) do
    expires_at = temp_email |> Map.get("expiresAt") |> to_datetime()
    address = temp_email["address"]
    domain = temp_email["domain"]

    attrs = %{
      user_id: user.id,
      address: address,
      domain: domain,
      expires_at: expires_at,
      is_permanent: permanent
    }

    %TempEmailSession{}
    |> TempEmailSession.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          user_id: user.id,
          expires_at: expires_at,
          is_permanent: permanent,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        ]
      ],
      conflict_target: :address
    )
  end

  defp year_from_now_ms, do: System.system_time(:millisecond) + 365 * 24 * 60 * 60 * 1000

  defp increment_stat(field) do
    today = Date.utc_today()

    Repo.transaction(fn ->
      stat =
        Repo.one(from(s in EmailStat, where: s.date == ^today and is_nil(s.domain_id), limit: 1))

      value = %{field => 1}

      case stat do
        nil ->
          %EmailStat{} |> EmailStat.changeset(Map.put(value, :date, today)) |> Repo.insert()

        stat ->
          stat |> Ecto.Changeset.change([{field, Map.get(stat, field) + 1}]) |> Repo.update()
      end
    end)

    :ok
  rescue
    _ -> :ok
  end

  defp dns_has_ownership_txt?(domain, token) do
    "_tempmail-verify.#{domain}"
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :txt)
    |> txt_records()
    |> Enum.any?(&(&1 == token))
  rescue
    _ -> false
  end

  defp dns_has_required_mx?(domain) do
    mail_server = mail_server_hostname()
    allowed = [String.downcase(mail_server), String.downcase("#{mail_server}.")]

    case :inet_res.lookup(String.to_charlist(domain), :in, :mx) do
      [] ->
        false

      records ->
        Enum.any?(records, fn
          {_priority, exchange} when is_list(exchange) ->
            exchange_matches?(exchange, allowed)

          exchange when is_list(exchange) ->
            exchange_matches?(exchange, allowed)

          _ ->
            false
        end)
    end
  rescue
    _ -> false
  end

  defp ensure_mailbox_domain_allowed(user, domain) do
    cond do
      system_mailbox_domain?(domain) ->
        :ok

      Repo.exists?(
        from(d in UserDomain,
          where:
            d.user_id == ^user.id and d.domain == ^domain and d.is_active == true and
                d.is_verified == true
        )
      ) ->
        :ok

      Repo.exists?(from(d in UserDomain, where: d.user_id == ^user.id and d.domain == ^domain)) ->
        {:error, :domain_not_verified}

      true ->
        {:error, :domain_not_allowed}
    end
  end

  # Operational prefixes (support@, contact@, ...) on system domains are off
  # limits for regular users so nobody can claim the service's own addresses.
  # Admins may create them, and users keep full freedom on their own domains.
  defp ensure_mailbox_prefix_allowed(user, prefix, domain) do
    if reserved_prefix?(prefix) and system_mailbox_domain?(domain) and
         user.role not in ["ADMIN", "SUPER_ADMIN"] do
      {:error, :reserved_prefix}
    else
      :ok
    end
  end

  defp system_mailbox_domain?(domain) do
    Repo.exists?(from(d in Domain, where: d.domain == ^domain and d.is_active == true)) ||
      (Repo.aggregate(from(d in Domain, where: d.is_active == true), :count) == 0 and
         domain == Application.get_env(:tempmail, :default_domain, "tempmail.com"))
  end

  defp exchange_matches?(exchange, allowed) do
    exchange
    |> List.to_string()
    |> String.downcase()
    |> then(&(&1 in allowed))
  end

  defp dns_has_spf?(domain) do
    domain
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :txt)
    |> txt_records()
    |> Enum.any?(fn record ->
      String.starts_with?(record, "v=spf1") and String.contains?(record, mail_server_hostname())
    end)
  rescue
    _ -> false
  end

  defp txt_records(records) do
    Enum.map(records, fn
      chunks when is_list(chunks) and is_list(hd(chunks)) ->
        chunks |> Enum.map(&List.to_string/1) |> Enum.join("")

      chars when is_list(chars) ->
        List.to_string(chars)

      value ->
        to_string(value)
    end)
  rescue
    _ -> []
  end

  defp maybe_dns_error(errors, true, _message), do: errors
  defp maybe_dns_error(errors, _result, message), do: [message | errors]

  defp setup_verified_domain(domain) do
    with {:ok, _} <- Mailcow.add_domain(domain) do
      Mailcow.create_catch_all_mailbox(domain)
      Mailcow.setup_catch_all(domain)
    end

    :ok
  rescue
    _ -> :ok
  end

  defp mail_server_hostname,
    do: Application.get_env(:tempmail, :mail_server_hostname, "mail.tempmailcentral.com")
end
