defmodule MyLib.Credentials.CredentialProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyLib.Credentials.Credential

  schema "credential_profiles" do
    field :status, :string
    field :address, :string
    field :full_name, :string
    field :ic, :string
    field :phone, :string
    field :date_of_birth, :date

    belongs_to :credential, Credential

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(credential_profile, attrs) do
    credential_profile
    |> cast(attrs, [:full_name, :ic, :status, :phone, :address, :date_of_birth, :credential_id])
    |> validate_required([
      :full_name,
      :ic,
      :status,
      :phone,
      :address,
      :date_of_birth,
      :credential_id
    ])
  end
end
