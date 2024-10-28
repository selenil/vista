defmodule Vista.AuctionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Vista.Auctions` context.
  """

  @doc """
  Generate a auction.
  """
  def auction_fixture(attrs \\ %{}) do
    {:ok, auction} =
      attrs
      |> Enum.into(%{})
      |> Vista.Auctions.create_auction()

    auction
  end

  @doc """
  Generate a bid.
  """
  def bid_fixture(attrs \\ %{}) do
    auction = auction_fixture()

    {:ok, bid} =
      attrs
      |> Enum.into(%{})
      |> then(&Vista.Auctions.create_bid(auction, &1))

    bid
  end
end
