defmodule MyLib.Repo do
  use Ecto.Repo,
    otp_app: :myLib,
    adapter: Ecto.Adapters.Postgres
end
