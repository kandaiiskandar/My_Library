defmodule MyLibWeb.CredentialSettingsLive do
  use MyLibWeb, :live_view

  alias MyLib.Credentials
  alias MyLib.Credentials.CredentialProfile

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/credentials/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_credential_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>

      <div>
        <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Profile Information</h3>
        <.simple_form
          for={@profile_form}
          id="profile_form"
          phx-submit="update_profile"
          phx-change="validate_profile"
        >
          <.input field={@profile_form[:full_name]} type="text" label="Full Name" required />
          <.input
            field={@profile_form[:ic]}
            type="text"
            label="IC Number"
            placeholder="123456789012"
            required
          />
          <.input
            field={@profile_form[:status]}
            type="select"
            label="Status"
            options={[{"Active", "active"}, {"Inactive", "inactive"}, {"Pending", "pending"}]}
            required
          />
          <.input
            field={@profile_form[:phone]}
            type="text"
            label="Phone Number"
            placeholder="+60123456789"
          />
          <.input field={@profile_form[:date_of_birth]} type="date" label="Date of Birth" />
          <.input field={@profile_form[:address]} type="textarea" label="Address" rows="3" />
          <:actions>
            <.button phx-disable-with="Saving...">
              {if @current_profile, do: "Update Profile", else: "Create Profile"}
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Credentials.update_credential_email(socket.assigns.current_credential, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/credentials/settings")}
  end

  def mount(_params, _session, socket) do
    credential = socket.assigns.current_credential
    profile = Credentials.get_credential_profile_by_credential_id(credential.id)
    email_changeset = Credentials.change_credential_email(credential)
    password_changeset = Credentials.change_credential_password(credential)
    profile_changeset = Credentials.change_credential_profile(profile)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, credential.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:profile_form, to_form(profile_changeset))
      |> assign(:current_profile, profile)
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_profile", %{"credential_profile" => profile_params}, socket) do
    profile = socket.assigns.current_profile || %CredentialProfile{}

    profile_form =
      profile
      |> Credentials.change_credential_profile(profile_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, profile_form: profile_form)}
  end

  def handle_event("update_profile", %{"credential_profile" => profile_params}, socket) do
    credential = socket.assigns.current_credential

    case socket.assigns.current_profile do
      nil ->
        # Create new profile
        case Credentials.create_credential_profile(credential, profile_params) do
          {:ok, profile} ->
            # Reload credential with profile for navigation update
            updated_credential = Credentials.get_credential!(credential.id)

            {:noreply,
             socket
             |> assign(:current_credential, updated_credential)
             |> assign(:current_profile, profile)
             |> assign(:profile_form, to_form(Credentials.change_credential_profile(profile)))
             |> put_flash(:info, "Profile created successfully.")}

          {:error, changeset} ->
            {:noreply, assign(socket, :profile_form, to_form(changeset))}
        end

      profile ->
        # Update existing profile
        case Credentials.update_credential_profile(profile, profile_params) do
          {:ok, updated_profile} ->
            # Reload credential with profile for navigation update
            updated_credential = Credentials.get_credential!(credential.id)

            {:noreply,
             socket
             |> assign(:current_credential, updated_credential)
             |> assign(:current_profile, updated_profile)
             |> assign(
               :profile_form,
               to_form(Credentials.change_credential_profile(updated_profile))
             )
             |> put_flash(:info, "Profile updated successfully.")}

          {:error, changeset} ->
            {:noreply, assign(socket, :profile_form, to_form(changeset))}
        end
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "credential" => credential_params} = params

    email_form =
      socket.assigns.current_credential
      |> Credentials.change_credential_email(credential_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "credential" => credential_params} = params
    credential = socket.assigns.current_credential

    case Credentials.apply_credential_email(credential, password, credential_params) do
      {:ok, applied_credential} ->
        Credentials.deliver_credential_update_email_instructions(
          applied_credential,
          credential.email,
          &url(~p"/credentials/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "credential" => credential_params} = params

    password_form =
      socket.assigns.current_credential
      |> Credentials.change_credential_password(credential_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "credential" => credential_params} = params
    credential = socket.assigns.current_credential

    case Credentials.update_credential_password(credential, password, credential_params) do
      {:ok, credential} ->
        password_form =
          credential
          |> Credentials.change_credential_password(credential_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
