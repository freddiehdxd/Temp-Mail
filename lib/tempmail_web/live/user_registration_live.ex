defmodule TempmailWeb.UserRegistrationLive do
  use TempmailWeb, :live_view

  alias Tempmail.Accounts
  alias Tempmail.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="relative -mt-16 flex min-h-screen items-center justify-center overflow-hidden bg-gradient-to-b from-indigo-50 via-white to-white px-4 py-24 sm:-mt-20">
      <div class="pointer-events-none absolute inset-0 overflow-hidden">
        <div class="absolute -left-40 top-0 h-96 w-96 rounded-full bg-purple-300 opacity-30 blur-3xl">
        </div>
        <div class="absolute -right-40 top-0 h-96 w-96 rounded-full bg-indigo-300 opacity-30 blur-3xl">
        </div>
        <div class="absolute bottom-0 left-1/2 h-96 w-96 -translate-x-1/2 rounded-full bg-pink-300 opacity-20 blur-3xl">
        </div>
        <div class="absolute inset-0 bg-[linear-gradient(to_right,#8882_1px,transparent_1px),linear-gradient(to_bottom,#8882_1px,transparent_1px)] bg-[size:24px_24px] opacity-20">
        </div>
      </div>

      <div class="relative z-10 w-full max-w-md">
        <div class="rounded-3xl p-8 shadow-xl glass">
          <div class="mb-8 text-center">
            <div class="mb-4 inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 shadow-lg shadow-indigo-500/25">
              <.icon name="hero-user-plus" class="h-8 w-8 text-white" />
            </div>
            <h1 class="mb-2 text-2xl font-bold">Register for an account</h1>
            <p class="text-slate-500">Create your TempMail account</p>
          </div>

          <div
            :if={@check_errors and @form_errors != []}
            class="mb-5 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm font-medium text-rose-700"
            role="alert"
          >
            <div :for={message <- @form_errors} class="flex gap-2">
              <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none" />
              <span>{message}</span>
            </div>
          </div>

          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in?_action=registered"}
            method="post"
            class="space-y-4"
          >
            <div>
              <label for={@form[:email].id} class="mb-2 block text-sm font-semibold text-slate-700">
                Email
              </label>
              <input
                id={@form[:email].id}
                name={@form[:email].name}
                value={@form[:email].value}
                type="email"
                required
                autocomplete="email"
                class={[
                  "h-12 w-full rounded-xl border bg-white px-4 text-sm font-medium text-slate-900 shadow-sm outline-none transition-all placeholder:text-slate-400 focus:ring-4",
                  @form[:email].errors == [] &&
                    "border-slate-200 focus:border-indigo-500 focus:ring-indigo-500/10",
                  @form[:email].errors != [] &&
                    "border-rose-300 focus:border-rose-500 focus:ring-rose-500/10"
                ]}
              />
              <.error :for={{msg, opts} <- @form[:email].errors}>
                {TempmailWeb.CoreComponents.translate_error({msg, opts})}
              </.error>
            </div>

            <div>
              <label
                for={@form[:password].id}
                class="mb-2 block text-sm font-semibold text-slate-700"
              >
                Password
              </label>
              <input
                id={@form[:password].id}
                name={@form[:password].name}
                type="password"
                required
                autocomplete="new-password"
                class={[
                  "h-12 w-full rounded-xl border bg-white px-4 text-sm font-medium text-slate-900 shadow-sm outline-none transition-all placeholder:text-slate-400 focus:ring-4",
                  @form[:password].errors == [] &&
                    "border-slate-200 focus:border-indigo-500 focus:ring-indigo-500/10",
                  @form[:password].errors != [] &&
                    "border-rose-300 focus:border-rose-500 focus:ring-rose-500/10"
                ]}
              />
              <.error :for={{msg, opts} <- @form[:password].errors}>
                {TempmailWeb.CoreComponents.translate_error({msg, opts})}
              </.error>
            </div>

            <button
              phx-disable-with="Creating account..."
              class="tm-btn-gradient h-12 w-full justify-center gap-2 text-base shadow-lg shadow-indigo-500/25"
            >
              Create an account <.icon name="hero-arrow-right" class="h-4 w-4" />
            </button>
          </.form>

          <div class="my-6 flex items-center gap-3">
            <div class="h-px flex-1 bg-slate-200"></div>
            <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Account</span>
            <div class="h-px flex-1 bg-slate-200"></div>
          </div>

          <.link
            navigate={~p"/users/log_in"}
            class="flex w-full items-center justify-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 font-medium text-slate-800 transition-all hover:bg-slate-50"
          >
            <.icon name="hero-arrow-left-on-rectangle" class="h-5 w-5 text-indigo-500" /> Log in
          </.link>

          <p class="mt-8 text-center text-sm text-slate-500">
            By creating an account, you agree to our
            <.link navigate={~p"/terms"} class="font-semibold text-indigo-600 hover:underline">
              Terms of Service
            </.link>
            and
            <.link navigate={~p"/privacy"} class="font-semibold text-indigo-600 hover:underline">
              Privacy Policy
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset = Map.put(changeset, :action, :insert)
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    form_errors = form_errors(changeset)

    if changeset.valid? do
      assign(socket, form: form, form_errors: form_errors, check_errors: false)
    else
      assign(socket, form: form, form_errors: form_errors)
    end
  end

  defp form_errors(%Ecto.Changeset{action: nil}), do: []

  defp form_errors(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      TempmailWeb.CoreComponents.translate_error({message, opts})
    end)
    |> Enum.flat_map(fn {field, messages} ->
      field = field |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      Enum.map(messages, &"#{field}: #{&1}")
    end)
  end
end
