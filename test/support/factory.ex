defmodule Vista.Factory do
  use ExMachina.Ecto, repo: Vista.Repo

  alias Vista.Accounts.User
  alias Vista.Auctions.Auction
  alias Vista.Auctions.Bid

  def user_factory do
    %User{
      email: sequence(:email, &"user-#{&1}@example.com"),
      hashed_password: "my-secure-password"
    }
  end

  def auction_factory do
    %Auction{
      title: "Auction-#{Ecto.UUID.generate()}",
      initial_price: 100,
      current_price: 100,
      end_date: DateTime.utc_now() |> DateTime.add(1, :day),
      status: :active,
      photo_url: "",
      user: build(:user)
    }
  end

  def bid_factory do
    %Bid{
      amount: 100,
      user: build(:user),
      auction: build(:auction)
    }
  end
end
