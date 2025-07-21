defmodule MyLib.CredentialsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MyLib.Credentials` context.
  """

  def unique_credential_email, do: "credential#{System.unique_integer()}@example.com"
  def valid_credential_password, do: "hello world!"

  def valid_credential_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_credential_email(),
      password: valid_credential_password()
    })
  end

  def credential_fixture(attrs \\ %{}) do
    {:ok, credential} =
      attrs
      |> valid_credential_attributes()
      |> MyLib.Credentials.register_credential()

    credential
  end

  def extract_credential_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
