dotenv_path =
  [
    Path.expand("../.env", __DIR__),
    Path.expand(".env", File.cwd!())
  ]
  |> Enum.uniq()
  |> Enum.find(&File.exists?/1)

if dotenv_path do
  dotenv_path
  |> File.read!()
  |> String.split(~r/\R/, trim: true)
  |> Enum.each(fn raw_line ->
    line = String.trim(raw_line)

    if line != "" and not String.starts_with?(line, "#") and String.contains?(line, "=") do
      [key, value] = String.split(line, "=", parts: 2)

      key = String.trim(key)

      value =
        value
        |> String.trim()
        |> String.trim_leading("\"")
        |> String.trim_trailing("\"")
        |> String.trim_leading("'")
        |> String.trim_trailing("'")

      if key != "" and System.get_env(key) in [nil, ""] do
        System.put_env(key, value)
      end
    end
  end)
end
