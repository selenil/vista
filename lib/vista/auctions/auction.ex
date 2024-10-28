defmodule Vista.Auctions.Auction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Vista.Accounts.User
  alias Vista.Auctions.Bid

  schema "auctions" do
    field :title, :string
    field :description, :string
    field :initial_price, :decimal
    field :current_price, :decimal
    field :end_date, :utc_datetime
    field :status, Ecto.Enum, values: [:active, :finished, :cancelled], default: :active
    field :photo_url, :string
    has_many :bids, Bid
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(auction, attrs) do
    auction
    |> cast(attrs, [
      :title,
      :description,
      :initial_price,
      :current_price,
      :end_date,
      :photo_url,
      :status,
      :user_id
    ])
    |> validate_required([
      :title,
      :initial_price,
      :current_price,
      :end_date,
      :status,
      :user_id
    ])
    |> validate_number(:initial_price, greater_than: 0)
  end
end
