defmodule Vista.Auctions.Bid do
  use Ecto.Schema
  import Ecto.Changeset

  alias Vista.Auctions.Auction
  alias Vista.Accounts.User

  schema "bids" do
    field :amount, :decimal
    belongs_to :auction, Auction
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(bid, attrs) do
    bid
    |> cast(attrs, [:amount, :auction_id, :user_id])
    |> validate_required([:amount, :auction_id, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:auction_id)
    |> foreign_key_constraint(:user_id)
  end
end
