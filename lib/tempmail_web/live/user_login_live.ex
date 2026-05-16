defmodule TempmailWeb.UserLoginLive do
  use TempmailWeb, :live_view

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
              <.icon name="hero-envelope" class="h-8 w-8 text-white" />
            </div>
            <h1 class="mb-2 text-2xl font-bold">Welcome to TempMail</h1>
            <p class="text-slate-500">Sign in to access your account</p>
          </div>

          <div class="space-y-3">
            <a
              href={~p"/auth/google"}
              class="flex w-full items-center justify-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 font-medium text-slate-800 transition-all hover:bg-slate-50"
            >
              <svg class="h-5 w-5" viewBox="0 0 24 24" aria-hidden="true">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              Continue with Google
            </a>

            <a
              href={~p"/auth/discord"}
              class="flex w-full items-center justify-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 font-medium text-slate-800 transition-all hover:bg-slate-50"
            >
              <svg
                class="h-5 w-5 text-[#5865F2]"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M20.317 4.369A19.791 19.791 0 0 0 15.364 2.8a13.686 13.686 0 0 0-.635 1.313 18.4 18.4 0 0 0-5.458 0A13.177 13.177 0 0 0 8.636 2.8a19.736 19.736 0 0 0-4.954 1.57C.543 9.03-.31 13.575.099 18.057a19.9 19.9 0 0 0 6.073 3.073 14.8 14.8 0 0 0 1.302-2.108 12.978 12.978 0 0 1-2.052-.987c.172-.126.34-.257.502-.391a14.152 14.152 0 0 0 12.152 0c.164.134.331.265.503.391-.65.389-1.337.72-2.053.987.375.735.812 1.441 1.302 2.108a19.866 19.866 0 0 0 6.074-3.073c.48-5.197-.82-9.701-3.585-13.688ZM8.02 15.331c-1.183 0-2.157-1.087-2.157-2.421 0-1.333.955-2.421 2.157-2.421 1.21 0 2.176 1.097 2.157 2.421 0 1.334-.955 2.421-2.157 2.421Zm7.96 0c-1.183 0-2.157-1.087-2.157-2.421 0-1.333.955-2.421 2.157-2.421 1.21 0 2.176 1.097 2.157 2.421 0 1.334-.946 2.421-2.157 2.421Z" />
              </svg>
              Continue with Discord
            </a>
          </div>

          <div class="my-6 flex items-center gap-3">
            <div class="h-px flex-1 bg-slate-200"></div>
            <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">
              or email
            </span>
            <div class="h-px flex-1 bg-slate-200"></div>
          </div>

          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log_in"}
            phx-update="ignore"
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
                class="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-sm font-medium text-slate-900 shadow-sm outline-none transition-all placeholder:text-slate-400 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10"
              />
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
                autocomplete="current-password"
                class="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-sm font-medium text-slate-900 shadow-sm outline-none transition-all placeholder:text-slate-400 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10"
              />
            </div>

            <div class="flex items-center justify-between gap-4">
              <label class="inline-flex items-center gap-2 text-sm font-medium text-slate-600">
                <input type="hidden" name={@form[:remember_me].name} value="false" />
                <input
                  id={@form[:remember_me].id}
                  name={@form[:remember_me].name}
                  type="checkbox"
                  value="true"
                  class="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                /> Keep me logged in
              </label>
              <.link
                href={~p"/users/reset_password"}
                class="text-sm font-semibold text-indigo-600 hover:text-indigo-700"
              >
                Forgot your password?
              </.link>
            </div>

            <button
              phx-disable-with="Logging in..."
              class="tm-btn-gradient h-12 w-full justify-center gap-2 text-base shadow-lg shadow-indigo-500/25"
            >
              Log in <.icon name="hero-arrow-right" class="h-4 w-4" />
            </button>
          </.form>

          <div class="my-6 flex items-center gap-3">
            <div class="h-px flex-1 bg-slate-200"></div>
            <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Account</span>
            <div class="h-px flex-1 bg-slate-200"></div>
          </div>

          <.link
            navigate={~p"/users/register"}
            class="flex w-full items-center justify-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 font-medium text-slate-800 transition-all hover:bg-slate-50"
          >
            <.icon name="hero-user-plus" class="h-5 w-5 text-indigo-500" /> Sign up
          </.link>

          <p class="mt-8 text-center text-sm text-slate-500">
            By signing in, you agree to our
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
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
