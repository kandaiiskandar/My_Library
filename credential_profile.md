# Credential Profile Implementation Guide

## Overview
This document outlines the implementation of a new `credential_profile` schema that belongs to a credential. Each credential has only one profile, and we'll add a form in the settings page for users to manage their profile information. Additionally, we'll replace the email display in navigation with the user's full name when available.

## Current System Analysis
- **Credential Schema**: Located in `lib/myLib/credentials/credential.ex`
- **Credentials Context**: Located in `lib/myLib/credentials.ex`
- **Settings Page**: Located in `lib/myLib_web/live/credential_settings_live.ex`
- **Navigation**: Located in `lib/myLib_web/components/layouts/root.html.heex`

## Implementation Plan

### 1. Create the CredentialProfile Schema

Create a new file: `lib/myLib/credentials/credential_profile.ex`

```elixir
defmodule MyLib.Credentials.CredentialProfile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "credential_profiles" do
    field :full_name, :string
    field :ic, :string  # Identity Card number
    field :status, :string
    field :phone, :string
    field :address, :text
    field :date_of_birth, :date
    
    belongs_to :credential, MyLib.Credentials.Credential

    timestamps(type: :utc_datetime)
  end

  def changeset(credential_profile, attrs) do
    credential_profile
    |> cast(attrs, [:full_name, :ic, :status, :phone, :address, :date_of_birth])
    |> validate_required([:full_name, :ic, :status])
    |> validate_length(:full_name, min: 2, max: 100)
    |> validate_length(:ic, min: 12, max: 12)  # Assuming Malaysian IC format
    |> validate_format(:ic, ~r/^\d{12}$/, message: "must be 12 digits")
    |> unique_constraint(:ic, message: "IC number already exists")
    |> validate_inclusion(:status, ["active", "inactive", "pending"])
  end
end
```

### 2. Create Migration

Create: `priv/repo/migrations/[timestamp]_create_credential_profiles.exs`

```elixir
defmodule MyLib.Repo.Migrations.CreateCredentialProfiles do
  use Ecto.Migration

  def change do
    create table(:credential_profiles) do
      add :full_name, :string, null: false
      add :ic, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :phone, :string
      add :address, :text
      add :date_of_birth, :date
      add :credential_id, references(:credentials, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:credential_profiles, [:ic])
    create unique_index(:credential_profiles, [:credential_id])
    create index(:credential_profiles, [:credential_id])
  end
end
```

### 3. Update Credential Schema

In `lib/myLib/credentials/credential.ex`, add the association in the schema block:

```elixir
# Add this in the schema block
has_one :credential_profile, MyLib.Credentials.CredentialProfile
```

### 4. Update Credentials Context

In `lib/myLib/credentials.ex`, add these functions:

```elixir
alias MyLib.Credentials.CredentialProfile

# Profile management functions
def get_credential_profile(credential) do
  Repo.get_by(CredentialProfile, credential_id: credential.id)
end

def get_credential_with_profile(id) do
  Credential
  |> Repo.get!(id)
  |> Repo.preload(:credential_profile)
end

def create_credential_profile(credential, attrs) do
  %CredentialProfile{}
  |> CredentialProfile.changeset(Map.put(attrs, "credential_id", credential.id))
  |> Repo.insert()
end

def update_credential_profile(profile, attrs) do
  profile
  |> CredentialProfile.changeset(attrs)
  |> Repo.update()
end

def change_credential_profile(profile \\ %CredentialProfile{}, attrs \\ %{}) do
  CredentialProfile.changeset(profile, attrs)
end
```

**Update existing getter functions to preload profile (Option A approach):**

```elixir
def get_credential_by_session_token(token) do
  {:ok, query} = CredentialToken.verify_session_token_query(token)
  
  query
  |> join(:left, [c], p in assoc(c, :credential_profile))
  |> preload([c, p], credential_profile: p)
  |> Repo.one()
end

def get_credential_by_email(email) when is_binary(email) do
  Credential
  |> Repo.get_by(email: email)
  |> case do
    nil -> nil
    credential -> Repo.preload(credential, :credential_profile)
  end
end

def get_credential!(id) do
  Credential
  |> Repo.get!(id)
  |> Repo.preload(:credential_profile)
end

def get_credential_by_email_and_password(email, password)
    when is_binary(email) and is_binary(password) do
  credential = 
    Credential
    |> Repo.get_by(email: email)
    |> case do
      nil -> nil
      cred -> Repo.preload(cred, :credential_profile)
    end
    
  if Credential.valid_password?(credential, password), do: credential
end
```

### 5. Update CredentialSettingsLive

In your existing `credential_settings_live.ex`, add these modifications:

**Update mount/3:**
```elixir
def mount(_params, _session, socket) do
  credential = socket.assigns.current_credential
  profile = Credentials.get_credential_profile(credential)
  
  email_changeset = Credentials.change_credential_email(credential)
  password_changeset = Credentials.change_credential_password(credential)
  profile_changeset = Credentials.change_credential_profile(profile || %CredentialProfile{})

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
```

**Add new event handlers:**
```elixir
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
          {:noreply, 
           socket 
           |> put_flash(:info, "Profile created successfully.")
           |> assign(:current_profile, profile)
           |> assign(:profile_form, to_form(Credentials.change_credential_profile(profile)))}
        
        {:error, changeset} ->
          {:noreply, assign(socket, :profile_form, to_form(changeset))}
      end
    
    profile ->
      # Update existing profile
      case Credentials.update_credential_profile(profile, profile_params) do
        {:ok, updated_profile} ->
          {:noreply, 
           socket 
           |> put_flash(:info, "Profile updated successfully.")
           |> assign(:current_profile, updated_profile)
           |> assign(:profile_form, to_form(Credentials.change_credential_profile(updated_profile)))}
        
        {:error, changeset} ->
          {:noreply, assign(socket, :profile_form, to_form(changeset))}
      end
  end
end
```

### 6. Update the Settings Template

In the `render/1` function of `credential_settings_live.ex`, add a new profile section after the password section:

```heex
<div>
  <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Profile Information</h3>
  <.simple_form
    for={@profile_form}
    id="profile_form"
    phx-submit="update_profile"
    phx-change="validate_profile"
  >
    <.input 
      field={@profile_form[:full_name]} 
      type="text" 
      label="Full Name" 
      required 
    />
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
    <.input 
      field={@profile_form[:date_of_birth]} 
      type="date" 
      label="Date of Birth" 
    />
    <.input 
      field={@profile_form[:address]} 
      type="textarea" 
      label="Address" 
      rows="3"
    />
    <:actions>
      <.button phx-disable-with="Saving...">
        <%= if @current_profile, do: "Update Profile", else: "Create Profile" %>
      </.button>
    </:actions>
  </.simple_form>
</div>
```

## Navigation Display Name Implementation

### 7. Add Helper Function

In `lib/myLib_web/components/core_components.ex`, add:

```elixir
def display_name(credential) do
  case credential.credential_profile do
    %{full_name: full_name} when not is_nil(full_name) and full_name != "" ->
      full_name
    _ ->
      credential.email
  end
end
```

### 8. Update Root Layout Template

In `lib/myLib_web/components/layouts/root.html.heex`, replace the email display:

**Current:**
```heex
<li class="text-[0.8125rem] leading-6 text-zinc-900">
  {@current_credential.email}
</li>
```

**New:**
```heex
<li class="text-[0.8125rem] leading-6 text-zinc-900">
  <%= display_name(@current_credential) %>
</li>
```

**Alternative without helper function:**
```heex
<li class="text-[0.8125rem] leading-6 text-zinc-900">
  <%= if @current_credential.credential_profile && @current_credential.credential_profile.full_name do %>
    <%= @current_credential.credential_profile.full_name %>
  <% else %>
    <%= @current_credential.email %>
  <% end %>
</li>
```

## Testing Considerations

### 9. Create Tests

Create `test/myLib/credentials/credential_profile_test.exs`:

```elixir
defmodule MyLib.Credentials.CredentialProfileTest do
  use MyLib.DataCase

  alias MyLib.Credentials.CredentialProfile

  describe "changeset/2" do
    test "validates required fields" do
      changeset = CredentialProfile.changeset(%CredentialProfile{}, %{})
      
      assert %{
        full_name: ["can't be blank"],
        ic: ["can't be blank"],
        status: ["can't be blank"]
      } = errors_on(changeset)
    end

    test "validates IC format" do
      attrs = %{full_name: "John Doe", ic: "invalid", status: "active"}
      changeset = CredentialProfile.changeset(%CredentialProfile{}, attrs)
      
      assert %{ic: ["must be 12 digits"]} = errors_on(changeset)
    end

    test "validates status inclusion" do
      attrs = %{full_name: "John Doe", ic: "123456789012", status: "invalid"}
      changeset = CredentialProfile.changeset(%CredentialProfile{}, attrs)
      
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end
end
```

### 10. Update Existing Tests

Update credential-related tests to handle preloaded profiles:

- `test/myLib/credentials_test.exs`
- `test/myLib_web/credential_auth_test.exs`
- `test/myLib_web/live/credential_settings_live_test.exs`

## Migration Steps

### 11. Implementation Order

1. **Create the schema and migration files**
2. **Run migration**: `mix ecto.migrate`
3. **Update the Credential schema** with association
4. **Update Credentials context** with new functions and preloading
5. **Update CredentialSettingsLive** with profile form
6. **Add helper function** for display name
7. **Update root layout template** for navigation
8. **Create and update tests**
9. **Test thoroughly** in development environment

## Key Benefits

- **One-to-One Relationship**: Each credential has exactly one profile
- **Clean Separation**: Profile data is separate from authentication data
- **Validation**: Proper validation for IC numbers and required fields
- **User-Friendly**: Simple form in the existing settings page
- **Extensible**: Easy to add more profile fields later
- **Consistent Data Access**: Profile always preloaded with credentials (Option A)
- **Graceful Fallback**: Shows email if no profile/name exists

## Performance Considerations

### Option A Advantages:
- **Simplicity**: One consistent way to fetch credentials throughout the app
- **Consistency**: All credential fetches will have profile data available
- **Maintainability**: No need to remember which functions preload and which don't
- **Future-proof**: Any feature that needs profile data will have it readily available

### Performance Impact:
- Minimal additional query overhead since it's a single LEFT JOIN
- Profile data will be available wherever credentials are used
- No N+1 query issues since it's preloaded at fetch time

## Backward Compatibility

- Existing code that accesses `credential.email` will continue to work
- New code can access `credential.credential_profile.full_name` when available
- Graceful fallback ensures users without profiles still see their email
- All existing authentication flows remain unchanged
