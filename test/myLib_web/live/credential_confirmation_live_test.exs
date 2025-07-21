defmodule MyLibWeb.CredentialConfirmationLiveTest do
  use MyLibWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MyLib.CredentialsFixtures

  alias MyLib.Credentials
  alias MyLib.Repo

  setup do
    %{credential: credential_fixture()}
  end

  describe "Confirm credential" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/credentials/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, credential: credential} do
      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_confirmation_instructions(credential, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Credential confirmed successfully"

      assert Credentials.get_credential!(credential.id).confirmed_at
      refute get_session(conn, :credential_token)
      assert Repo.all(Credentials.CredentialToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Credential confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_credential(credential)

      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, credential: credential} do
      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Credential confirmation link is invalid or it has expired"

      refute Credentials.get_credential!(credential.id).confirmed_at
    end
  end
end
