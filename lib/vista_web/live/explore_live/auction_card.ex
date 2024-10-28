defmodule VistaWeb.ExploreLive.AuctionCard do
  @moduledoc """
  LiveComponent for rendering an individual auction card.
  """

  use VistaWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full min-w-fit">
      <.card class="flex flex-col h-full min-w-fit">
        <.card_header class="p-0">
          <img
            src={@auction.photo_url}
            alt={"#{@auction.title}_photo"}
            class="w-full h-48 object-cover rounded-xl"
          />
        </.card_header>

        <.card_footer class="mt-8 flex flex-col gap-y-2">
          <.card_title class="text-lg text-wrap"><%= @auction.title %></.card_title>
          <p class="text-sm text-gray-500">Ends in: <%= format_date(@auction.end_date) %></p>
        </.card_footer>
      </.card>
      <.link navigate={~p"/auctions/#{@auction.id}"} class="mt-4">
        <.button class="w-full">Bid Now</.button>
      </.link>
    </div>
    """
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
end
