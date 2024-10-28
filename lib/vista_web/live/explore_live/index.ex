defmodule VistaWeb.ExploreLive do
  use VistaWeb, :live_view

  alias Vista.Auctions
  alias VistaWeb.ExploreLive.{AuctionForm, AuctionCard}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Auctions.subscribe()
      {:ok, setup_connected_socket(socket)}
    else
      {:ok, assign(socket, loading: true)}
    end
  end

  @impl true
  def render(%{loading: true} = assigns) do
    ~H"""
    <div role="status" class="loading-screen">Vista is loading...</div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="time-zone-hook" phx-hook="TimeZoneHook">
      <div class="flex w-full">
        <div class="container mx-auto space-y-16">
          <.header>
            <h1 class="text-3xl font-bold">Active Auctions</h1>
            <:actions>
              <.button phx-click={show_modal("create_auction")}>Create auction</.button>
            </:actions>
          </.header>

          <div id="auctions" phx-update="stream" class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div :for={{id, auction} <- @streams.auctions} id={id} class="flex flex-col">
              <.live_component module={AuctionCard} id={"auction-#{auction.id}"} auction={auction} />
            </div>
          </div>

          <.modal id="create_auction">
            <.live_component
              module={AuctionForm}
              id="create_auction_form"
              current_user={@current_user}
              user_timezone={@user_timezone}
            />
          </.modal>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_timezone", %{"timezone" => timezone}, socket) do
    {:noreply, assign(socket, user_timezone: timezone)}
  end

  @impl true
  def handle_info({:auction_created, auction}, socket) do
    %{current_user: %{email: email}} = socket.assigns

    socket =
      socket
      |> put_flash(:info, "#{email} just created an auction")
      |> stream_insert(:auctions, auction, at: 0)

    {:noreply, socket}
  end

  defp setup_connected_socket(socket) do
    socket
    |> assign(loading: false)
    |> stream(:auctions, Auctions.list_active_auctions())
    |> assign(:user_timezone, "Etc/UTC")
  end
end
