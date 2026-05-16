defmodule Tempmail.Integrations.Postfix do
  @postfix_main_cf "/etc/postfix/main.cf"
  @postfix_transport "/etc/postfix/transport"
  @postfix_virtual_mailbox "/etc/postfix/virtual_mailbox"

  def add_domain(domain) do
    with :ok <- add_to_virtual_domains(domain),
         :ok <- add_to_transport(domain),
         :ok <- add_to_virtual_mailbox(domain),
         :ok <- rebuild_and_reload() do
      {:ok, domain}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def remove_domain(domain) do
    with :ok <- remove_from_virtual_domains(domain),
         :ok <- remove_from_transport(domain),
         :ok <- remove_from_virtual_mailbox(domain),
         :ok <- rebuild_and_reload() do
      {:ok, domain}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def dns_instructions(domain) do
    hostname = Application.get_env(:tempmail, :mail_server_hostname, "mail.tempmailcentral.com")

    %{
      mx_record: %{type: "MX", name: "@", value: hostname, priority: 10},
      spf_record: %{
        type: "TXT",
        name: "@",
        value: "v=spf1 mx a include:#{hostname} -all"
      },
      dmarc_record: %{
        type: "TXT",
        name: "_dmarc",
        value: "v=DMARC1; p=quarantine; rua=mailto:postmaster@tempmailcentral.com"
      },
      verification_record: %{
        type: "TXT",
        name: "_tempmail-verify",
        value: "will-be-set-per-domain"
      }
    }
  end

  defp add_to_virtual_domains(domain) do
    content = File.read!(@postfix_main_cf)

    case Regex.run(~r/^virtual_mailbox_domains\s*=\s*(.*)$/m, content) do
      [full_match, current_domains] ->
        if String.contains?(current_domains, domain) do
          :ok
        else
          new_domains = "#{String.trim(current_domains)}, #{domain}"
          new_content = String.replace(content, full_match, "virtual_mailbox_domains = #{new_domains}")
          File.write!(@postfix_main_cf, new_content)
          :ok
        end

      nil ->
        File.write!(@postfix_main_cf, content <> "\nvirtual_mailbox_domains = #{domain}\n")
        :ok
    end
  end

  defp add_to_transport(domain) do
    content = File.read!(@postfix_transport)

    if String.contains?(content, domain) do
      :ok
    else
      File.write!(@postfix_transport, String.trim_trailing(content) <> "\n#{domain}    tempmail:\n")
      :ok
    end
  end

  defp add_to_virtual_mailbox(domain) do
    content = File.read!(@postfix_virtual_mailbox)
    escaped = String.replace(domain, ".", "\\.")
    regex_line = "/^.*@#{escaped}$/    OK"

    if String.contains?(content, escaped) do
      :ok
    else
      File.write!(@postfix_virtual_mailbox, String.trim_trailing(content) <> "\n#{regex_line}\n")
      :ok
    end
  end

  defp remove_from_virtual_domains(domain) do
    content = File.read!(@postfix_main_cf)

    case Regex.run(~r/^virtual_mailbox_domains\s*=\s*(.*)$/m, content) do
      [full_match, current_domains] ->
        new_domains =
          current_domains
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == domain))
          |> Enum.join(", ")

        new_content = String.replace(content, full_match, "virtual_mailbox_domains = #{new_domains}")
        File.write!(@postfix_main_cf, new_content)
        :ok

      nil ->
        :ok
    end
  end

  defp remove_from_transport(domain) do
    content = File.read!(@postfix_transport)

    new_content =
      content
      |> String.split("\n")
      |> Enum.reject(&String.starts_with?(&1, domain))
      |> Enum.join("\n")

    File.write!(@postfix_transport, new_content)
    :ok
  end

  defp remove_from_virtual_mailbox(domain) do
    content = File.read!(@postfix_virtual_mailbox)
    escaped = String.replace(domain, ".", "\\.")

    new_content =
      content
      |> String.split("\n")
      |> Enum.reject(&String.contains?(&1, escaped))
      |> Enum.join("\n")

    File.write!(@postfix_virtual_mailbox, new_content)
    :ok
  end

  defp rebuild_and_reload do
    case System.cmd("postmap", [@postfix_transport], stderr_to_stdout: true) do
      {_, 0} ->
        case System.cmd("systemctl", ["reload", "postfix"], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {output, _} -> {:error, "Failed to reload postfix: #{output}"}
        end

      {output, _} ->
        {:error, "Failed to rebuild transport map: #{output}"}
    end
  end
end
