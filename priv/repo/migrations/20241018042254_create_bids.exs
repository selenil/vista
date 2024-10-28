defmodule Vista.Repo.Migrations.CreateBids do
  use Ecto.Migration

  def change do
    create table(:bids) do
      add :amount, :decimal, null: false
      add :auction_id, references(:auctions, on_delete: :restrict), null: false
      add :user_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:bids, [:auction_id])
    create index(:bids, [:user_id])
  end
end
