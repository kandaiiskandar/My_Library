defmodule MyLib.Repo.Migrations.CreateCredentialProfiles do
  use Ecto.Migration

  def change do
    create table(:credential_profiles) do
      add :full_name, :string
      add :ic, :string
      add :status, :string, null: false, default: "pending"
      add :phone, :string
      add :address, :string
      add :date_of_birth, :date
      add :credential_id, references(:credentials, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:credential_profiles, [:ic])
    create unique_index(:credential_profiles, [:credential_id])
  end
end
