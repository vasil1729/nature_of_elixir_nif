defmodule Lab.Repo do
  use Ecto.Repo,
    otp_app: :lab_runner,
    adapter: Ecto.Adapters.Postgres
end
