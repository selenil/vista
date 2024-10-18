defmodule Vista.Repo do
  use Ecto.Repo,
    otp_app: :vista,
    adapter: Ecto.Adapters.Postgres
end
