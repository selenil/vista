defmodule Vista.Repo.Migrations.CreateAuctions do
  use Ecto.Migration

  def change do
    create table(:auctions) do
      add :title, :string, null: false
      add :description, :text
      add :initial_price, :decimal, null: false
      add :current_price, :decimal
      add :start_date, :utc_datetime, null: false
      add :end_date, :utc_datetime, null: false
      add :status, :string, null: false
      add :user_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:auctions, [:user_id])
    create index(:auctions, [:status])
  end
end
