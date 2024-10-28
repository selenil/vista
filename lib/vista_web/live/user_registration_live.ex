defmodule VistaWeb.UserRegistrationLive do
  use VistaWeb, :live_view

  alias Vista.Accounts
  alias Vista.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <section phx-drop-target={@uploads.avatar.ref}>
        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />
          <.label for="avatar-upload">
            Profile picture
          </.label>
          <.live_file_input id="avatar-upload" upload={@uploads.avatar} />

          <%= for entry <- @uploads.avatar.entries do %>
            <article class="upload-entry">
              <figure>
                <.live_img_preview entry={entry} />
                <figcaption><%= entry.client_name %></figcaption>
              </figure>

              <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>

              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                aria-label="cancel"
              >
                &times;
              </button>

              <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                <p class="alert alert-danger"><%= error_to_string(err) %></p>
              <% end %>
            </article>
          <% end %>

          <%= for err <- upload_errors(@uploads.avatar) do %>
            <p class="alert alert-danger"><%= error_to_string(err) %></p>
          <% end %>

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
          </:actions>
        </.simple_form>
      </section>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1
      )
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user_params
    |> Map.put("avatar_url", List.first(consume_file(socket)))
    |> Accounts.register_user()
    |> case do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset =
          Accounts.change_user_registration(user)

        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp consume_file(socket) do
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
      dest = Path.join([:code.priv_dir(:vista), "static", "uploads", Path.basename(path)])
      File.cp!(path, dest)
      {:postpone, ~p"/uploads/#{Path.basename(dest)}"}
    end)
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
end
