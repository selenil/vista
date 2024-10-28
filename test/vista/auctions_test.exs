defmodule Vista.AuctionsTest do
  use Vista.DataCase

  alias Vista.Auctions
  alias Vista.Auctions.Auction
  import Vista.Factory

  describe "auctions" do
    test "list_active_auctions/0 returns all active auctions ordered by end_date" do
      # Create auctions with different end dates using Vista.Factory
      earlier_date = DateTime.utc_now() |> DateTime.add(1, :day)
      later_date = DateTime.utc_now() |> DateTime.add(2, :day)
      past_date = DateTime.utc_now() |> DateTime.add(-1, :day)

      active1 = insert(:auction, end_date: earlier_date, status: :active)
      active2 = insert(:auction, end_date: later_date, status: :active)
      _inactive = insert(:auction, end_date: earlier_date, status: :finished)
      past = insert(:auction, end_date: past_date, status: :active)

      auctions = Auctions.list_active_auctions()

      assert length(auctions) == 3
      assert [first, second, third] = auctions
      # Later date should be first
      assert first.id == active2.id
      assert second.id == active1.id
      assert third.id == past.id
    end

    test "list_active_auctions/0 returns empty list when no active auctions exist" do
      insert(:auction, status: :finished)
      assert Auctions.list_active_auctions() == []
    end

    test "get_auction!/1 returns the auction with given id" do
      auction = insert(:auction)
      assert Auctions.get_auction!(auction.id).id == auction.id
    end

    test "create_auction/1 with valid data creates a auction" do
      user = insert(:user)

      valid_attrs = %{
        title: "My Title",
        description: "My Description",
        status: :active,
        end_date: DateTime.utc_now(),
        initial_price: Decimal.new(1),
        current_price: Decimal.new(1),
        photo_url: "",
        user_id: user.id
      }

      assert {:ok, %Auction{} = auction} = Auctions.create_auction(valid_attrs)
      assert auction.title == valid_attrs.title
      assert auction.description == valid_attrs.description
      assert auction.status == valid_attrs.status
      assert auction.initial_price == valid_attrs.initial_price
      assert auction.current_price == valid_attrs.current_price
      assert auction.user_id == valid_attrs.user_id
    end

    test "create_auction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Auctions.create_auction(%{"title" => nil})
    end

    test "update_auction/2 with valid data updates the auction" do
      auction = insert(:auction, %{status: :active, end_date: DateTime.utc_now()})
      update_attrs = %{}

      assert {:ok, %Auction{} = updated_auction} = Auctions.update_auction(auction, update_attrs)
      assert updated_auction.id == auction.id
    end

    test "update_auction/2 with invalid data returns error changeset" do
      auction = insert(:auction)

      assert {:error, %Ecto.Changeset{}} =
               Auctions.update_auction(auction, %{status: :invalid_status})

      assert auction.id == Auctions.get_auction!(auction.id).id
    end

    test "delete_auction/1 deletes the auction" do
      auction = insert(:auction, %{status: :active, end_date: DateTime.utc_now()})
      assert {:ok, %Auction{}} = Auctions.delete_auction(auction)
      assert_raise Ecto.NoResultsError, fn -> Auctions.get_auction!(auction.id) end
    end

    test "change_auction/1 returns a auction changeset" do
      auction = insert(:auction, %{status: :active, end_date: DateTime.utc_now()})
      assert %Ecto.Changeset{} = Auctions.change_auction(auction)
    end

    test "close_auction/1 closes auction and returns winner with highest bid" do
      user1 = insert(:user)
      user2 = insert(:user)
      auction = insert(:auction, %{status: :active})

      {:ok, _bid1} =
        Auctions.place_bid(auction.id, %{
          "amount" => 200,
          "user_id" => user1.id
        })

      {:ok, _bid2} =
        Auctions.place_bid(auction.id, %{
          "amount" => 300,
          "user_id" => user2.id
        })

      winner = Auctions.close_auction(auction)

      updated_auction = Auctions.get_auction!(auction.id)
      assert updated_auction.status == :finished
      # User with highest bid
      assert winner == user2
    end

    test "close_auction/1 returns nil when closing auction with no bids" do
      auction = insert(:auction, %{status: :active})

      winner = Auctions.close_auction(auction)

      updated_auction = Auctions.get_auction!(auction.id)
      assert updated_auction.status == :finished
      assert winner == nil
    end
  end

  describe "bids" do
    alias Vista.Auctions.Bid

    import Vista.AuctionsFixtures

    @invalid_attrs %{invalid_field: :invalid_value}

    test "list_bids/0 returns all bids" do
      bid = insert(:bid)
      bids = Auctions.list_bids()

      first = List.first(bids)
      assert length(bids) == 1
      assert first.id == bid.id
    end

    test "get_bid!/1 returns the bid with given id" do
      bid = insert(:bid, amount: 100)
      assert Auctions.get_bid!(bid.id).id == bid.id
    end

    test "create_bid/1 with valid data creates a bid" do
      user = insert(:user)
      auction = insert(:auction)

      attrs = %{
        "amount" => 120,
        "user_id" => user.id
      }

      assert {:ok, %Bid{} = bid} = Auctions.create_bid(auction, attrs)
      assert bid.amount == Decimal.new(120)
      assert bid.user_id == user.id
      assert bid.auction_id == auction.id
    end

    test "create_bid/1 with invalid data returns error changeset" do
      auction = insert(:auction)
      assert {:error, %Ecto.Changeset{}} = Auctions.create_bid(auction, %{"amount" => nil})
    end

    test "place_bid/1 places valid bid and updates auction price" do
      user = insert(:user)
      auction = insert(:auction, %{status: :active, current_price: 100})

      {:ok, {updated_auction, bid}} =
        Auctions.place_bid(auction.id, %{
          "amount" => 150,
          "user_id" => user.id
        })

      assert updated_auction.current_price == Decimal.new(150)
      assert bid.amount == Decimal.new(150)
      assert bid.user_id == user.id
    end

    test "place_bid/1 fails to place bid on inactive auction" do
      user = insert(:user)
      auction = insert(:auction, %{status: :finished})

      result =
        Auctions.place_bid(auction.id, %{
          "amount" => 150,
          "user_id" => user.id
        })

      assert {:error, "auction is not active"} = result
    end

    test "place_bid/1 fails to place bid lower than current price" do
      user = insert(:user)
      auction = insert(:auction, %{status: :active, current_price: 100})

      result =
        Auctions.place_bid(auction.id, %{
          "amount" => 90,
          "user_id" => user.id
        })

      assert {:error, %Ecto.Changeset{}} = result
      # Price shouldn't change
      assert auction.current_price == Decimal.new(100)
    end

    test "place_bid/1 fails to place bid on expired auction" do
      user = insert(:user)
      past_date = DateTime.utc_now() |> DateTime.add(-1, :hour)
      auction = insert(:auction, %{status: :active, end_date: past_date})

      result =
        Auctions.place_bid(auction.id, %{
          "amount" => 150,
          "user_id" => user.id
        })

      assert {:error, "auction has ended"} = result
    end

    test "update_bid/2 with valid data updates the bid" do
      bid = insert(:bid)
      update_attrs = %{}

      assert {:ok, %Bid{} = bid} = Auctions.update_bid(bid, update_attrs)
    end

    test "update_bid/2 with invalid data returns error changeset" do
      bid = insert(:bid)
      assert {:error, %Ecto.Changeset{}} = Auctions.update_bid(bid, %{"amount" => nil})
      assert bid.id == Auctions.get_bid!(bid.id).id
    end

    test "delete_bid/1 deletes the bid" do
      bid = insert(:bid)
      assert {:ok, %Bid{}} = Auctions.delete_bid(bid)
      assert_raise Ecto.NoResultsError, fn -> Auctions.get_bid!(bid.id) end
    end

    test "change_bid/1 returns a bid changeset" do
      bid = insert(:bid)
      assert %Ecto.Changeset{} = Auctions.change_bid(bid)
    end
  end
end
