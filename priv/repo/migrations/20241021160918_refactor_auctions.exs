defmodule Vista.Repo.Migrations.RefactorActionPictures do
  use Ecto.Migration

  def change do
    alter table(:auctions) do
      add :photo_url, :string
      remove :start_date
    end
  end
end
