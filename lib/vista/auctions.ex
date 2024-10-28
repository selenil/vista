defmodule Vista.Auctions do
  @moduledoc """
  The Auctions context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Changeset
  alias Vista.Auctions.Auction
  alias Vista.Repo
  alias Vista.Auctions.Bid

  use Vista.Realtime, :auctions

  @doc """
  Lists all active auctions, ordered by their end date (newest first).
  """
  def list_active_auctions do
    Auction
    |> where([a], a.status == :active)
    |> order_by([a], desc: a.end_date)
    |> Repo.all()
  end

  @doc """
  Gets a single auction.

  Raises `Ecto.NoResultsError` if the Auction does not exist.

  ## Examples

      iex> get_auction!(123)
      %Auction{}

      iex> get_auction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_auction!(id), do: Repo.get!(Auction, id)

  @doc """
  Creates a new auction with associated picture.

  ## Parameters
    - attrs: A map containing `:auction` and `:picture` keys
  """
  def create_auction(attrs \\ %{auction: %{}, picture: nil}) do
    %Auction{}
    |> Auction.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:auction_created)
  end

  @doc """
  Updates a auction.

  ## Examples

      iex> update_auction(auction, %{field: new_value})
      {:ok, %Auction{}}

      iex> update_auction(auction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_auction(%Auction{} = auction, attrs) do
    auction
    |> Auction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a auction.

  ## Examples

      iex> delete_auction(auction)
      {:ok, %Auction{}}

      iex> delete_auction(auction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_auction(%Auction{} = auction) do
    Repo.delete(auction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking auction changes.

  ## Examples

      iex> change_auction(auction)
      %Ecto.Changeset{data: %Auction{}}

  """
  def change_auction(%Auction{} = auction, attrs \\ %{}) do
    Auction.changeset(auction, attrs)
  end

  @doc """
  Closes an auction and determines its winner.

  Returns `{:ok, winner}` where winner is the user with highest bid,
  or `{:ok, nil}` if no bids were placed.
  """
  def close_auction(%Auction{} = auction) do
    auction
    |> Auction.changeset(%{status: :finished})
    |> Repo.update!()

    get_auction_winner(auction.id)
  end

  @doc """
  Returns the list of bids.

  ## Examples

      iex> list_bids()
      [%Bid{}, ...]

  """
  def list_bids do
    Repo.all(Bid)
  end

  @doc """
  Gets a single bid.

  Raises `Ecto.NoResultsError` if the Bid does not exist.

  ## Examples

      iex> get_bid!(123)
      %Bid{}

      iex> get_bid!(456)
      ** (Ecto.NoResultsError)

  """
  def get_bid!(id), do: Repo.get!(Bid, id)

  @doc """
  Creates a bid.

  ## Examples

      iex> create_bid(%{field: value})
      {:ok, %Bid{}}

      iex> create_bid(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_bid(auction, attrs \\ %{}) do
    %Bid{}
    |> Bid.changeset(Map.put(attrs, "auction_id", auction.id))
    |> validate_bid(auction)
    |> Repo.insert()
  end

  @doc """
  Places a bid in an active auction.

  Handles the entire bidding process atomically, including:
  - Validating the auction is still active
  - Validating the bid amount
  - Updating the auction's current price
  - Broadcasting the bid to connected clients

  Uses REPEATABLE READ isolation to prevent race conditions.
  """
  def place_bid(auction_id, bid_attrs \\ %{}) do
    # Set the transaction isolation level to REPEATABLE READ.
    # This will abort the transaction if the row has been modified
    Repo.query!("SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ")

    Repo.transaction(fn ->
      locked_auction = Repo.get!(Auction, auction_id, lock: "FOR UPDATE")

      with {:ok, valid_auction} <- validate_auction_status(locked_auction),
           {:ok, valid_bid} <- create_bid(valid_auction, bid_attrs),
           {:ok, updated_auction} <- update_auction_price(valid_auction, valid_bid.amount) do
        broadcast({updated_auction, valid_bid}, :bid_placed)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Updates a bid.

  ## Examples

      iex> update_bid(bid, %{field: new_value})
      {:ok, %Bid{}}

      iex> update_bid(bid, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_bid(%Bid{} = bid, attrs) do
    bid
    |> Bid.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a bid.

  ## Examples

      iex> delete_bid(bid)
      {:ok, %Bid{}}

      iex> delete_bid(bid)
      {:error, %Ecto.Changeset{}}

  """
  def delete_bid(%Bid{} = bid) do
    Repo.delete(bid)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bid changes.

  ## Examples

      iex> change_bid(bid)
      %Ecto.Changeset{data: %Bid{}}

  """
  def change_bid(%Bid{} = bid, attrs \\ %{}) do
    Bid.changeset(bid, attrs)
  end

  defp validate_auction_status(%Auction{} = auction) do
    cond do
      auction.status != :active ->
        {:error, "auction is not active"}

      DateTime.compare(auction.end_date, DateTime.utc_now()) == :lt ->
        {:error, "auction has ended"}

      true ->
        {:ok, auction}
    end
  end

  defp validate_bid(bid_changeset, auction) do
    bid_amount = Changeset.get_field(bid_changeset, :amount)

    cond do
      is_nil(bid_amount) ->
        Changeset.add_error(bid_changeset, :amount, "must be provided")

      bid_amount <= auction.current_price ->
        Changeset.add_error(
          bid_changeset,
          :amount,
          "must be higher than the current price (#{auction.current_price})"
        )

      true ->
        bid_changeset
    end
  end

  defp update_auction_price(%Auction{} = auction, amount) do
    auction
    |> Auction.changeset(%{current_price: amount})
    |> Repo.update()
  end

  defp get_auction_winner(auction_id) do
    auction =
      Auction
      |> Repo.get!(auction_id)
      |> Repo.preload(bids: [:user])

    case auction.bids do
      [] -> nil
      bids -> Enum.max_by(bids, & &1.amount).user
    end
  end
end
