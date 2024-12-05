defmodule VistaWeb.AuctionLive do
  use VistaWeb, :live_view
  alias Vista.Auctions
  alias Vista.Auctions.{Auction, Bid}

  # Time constants in seconds
  @seconds_per_day 86_400
  @seconds_per_hour 3_600
  @seconds_per_minute 60

  @type time_components ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Auctions.subscribe()
    end

    auction = Auctions.get_auction!(id)

    {:ok,
     socket
     |> assign_initial_state(auction)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="time-zone-hook" phx-hook="TimeZoneHook">
      <.auction_container auction_finished={@auction_finished}>
        <.auction_details {assigns} />
        <.bidding_form {assigns} />
      </.auction_container>
      <.auction_finished_overlay {assigns} />
    </div>
    """
  end

  @impl true
  def handle_event("place_bid", %{"bid" => bid_params}, socket) do
    handle_place_bid(socket, bid_params)
  end

  @impl true
  def handle_event("set_timezone", %{"timezone" => timezone}, socket) do
    {:noreply,
     socket
     |> assign(:user_timezone, timezone)
     |> update_time_left()
     |> start_timer()}
  end

  @impl true
  def handle_info(:init_timezone, socket) do
    {:noreply,
     socket
     |> push_event("get_timezone", %{})
     |> update_time_left()}
  end

  @impl true
  def handle_info({:bid_placed, auction_update}, socket) do
    {:noreply, handle_bid_notification(socket, auction_update)}
  end

  @impl true
  def handle_info(:tick, socket), do: handle_timer_tick(socket)

  @impl true
  def handle_info(:auction_finished, socket) do
    winner = Auctions.close_auction(socket.assigns.auction)
    {:noreply, finish_auction(socket, winner)}
  end

  defp assign_initial_state(socket, auction) do
    socket
    |> assign(:auction, auction)
    |> assign(:auction_finished, false)
    |> assign(:winner, nil)
    |> assign(:form, to_form(Auctions.change_bid(%Bid{})))
    |> assign(:bid_error, nil)
    |> assign(:user_timezone, "Etc/UTC")
    |> assign(:time_left, nil)
  end

  # Time handling
  defp start_timer(socket) do
    if not socket.assigns.auction_finished do
      Process.send_after(self(), :tick, 0)
    end

    socket
  end

  @spec calculate_remaining_time(DateTime.t()) :: non_neg_integer()
  defp calculate_remaining_time(end_date) do
    now = DateTime.utc_now()

    case DateTime.compare(end_date, now) do
      :gt -> DateTime.diff(end_date, now)
      _ -> 0
    end
  end

  @spec format_time(non_neg_integer()) :: String.t()
  defp format_time(seconds) when seconds <= 0, do: "00:00:00"

  defp format_time(seconds) do
    {days, hours, minutes, seconds} = break_down_time(seconds)

    [days, hours, minutes, seconds]
    |> Enum.map(&pad_number/1)
    |> join_time_components(days > 0)
  end

  @spec break_down_time(non_neg_integer()) :: time_components()
  defp break_down_time(total_seconds) do
    days = div(total_seconds, @seconds_per_day)
    remainder = rem(total_seconds, @seconds_per_day)

    hours = div(remainder, @seconds_per_hour)
    remainder = rem(remainder, @seconds_per_hour)

    minutes = div(remainder, @seconds_per_minute)
    seconds = rem(remainder, @seconds_per_minute)

    {days, hours, minutes, seconds}
  end

  defp pad_number(num), do: String.pad_leading(Integer.to_string(num), 2, "0")

  defp join_time_components([days, hours, minutes, seconds], true) do
    "#{days}:#{hours}:#{minutes}:#{seconds}"
  end

  defp join_time_components([_days, hours, minutes, seconds], false) do
    "#{hours}:#{minutes}:#{seconds}"
  end

  defp format_date(date, timezone) do
    date
    |> DateTime.shift_zone!(timezone)
    |> Calendar.strftime("%B %d, %Y at %I:%M %p %Z")
  end

  # Bid handling
  defp handle_place_bid(socket, bid_params) do
    current_price = socket.assigns.auction.current_price

    case process_bid(socket, bid_params) do
      {:ok, {_user_email, auction, _bid}} ->
        {:noreply,
         socket
         |> push_event("bid_finished", %{})
         |> update_auction(auction)}

      {:error, changeset} ->
        {:noreply, handle_bid_error(socket, changeset, current_price)}
    end
  end

  defp process_bid(socket, bid_params) do
    bid_params
    |> Map.put("user_id", socket.assigns.current_user.id)
    |> then(&Auctions.place_bid(socket.assigns.current_user.email, socket.assigns.auction.id, &1))
  end

  defp handle_bid_error(socket, changeset, current_price) do
    socket
    |> assign(:bid_error, changeset)
    |> assign(:auction, %{socket.assigns.auction | current_price: current_price})
    |> push_event("bid_finished", %{error: true, current_price: current_price})
  end

  defp handle_bid_notification(socket, {user_email, updated_auction, bid}) do
    socket
    |> put_flash(:info, "#{user_email} has made a bid of $#{bid.amount}")
    |> update_auction(updated_auction)
  end

  defp update_auction(socket, auction) do
    assign(socket, auction: auction)
  end

  # Timer Handling
  defp handle_timer_tick(%{assigns: assigns} = socket) do
    remaining_time = calculate_remaining_time(assigns.auction.end_date)

    cond do
      # Auction already finished
      assigns.auction_finished ->
        {:noreply, socket}

      # Time is up, finish the auction
      remaining_time <= 0 ->
        send(self(), :auction_finished)
        {:noreply, socket}

      # Continue the timer with exact intervals
      true ->
        Process.send_after(self(), :tick, calculate_next_tick_interval(remaining_time))
        {:noreply, assign(socket, :time_left, remaining_time)}
    end
  end

  # Calculate the next tick interval to ensure synchronization
  defp calculate_next_tick_interval(remaining_time) do
    if remaining_time > @seconds_per_minute do
      # Sync to the next second boundary
      current_ms = :os.system_time(:millisecond)
      next_second = div(current_ms + 1000, 1000) * 1000
      max(next_second - current_ms, 0)
    else
      # Update every 100ms for the final minute
      100
    end
  end

  defp update_time_left(%{assigns: %{user_timezone: user_timezone}} = socket) do
    case user_timezone do
      "Etc/UTC" ->
        # Don't update if we haven't received the real timezone yet
        socket

      timezone when is_binary(timezone) ->
        assign(socket, :time_left, calculate_remaining_time(socket.assigns.auction.end_date))
    end
  end

  # Helpers
  defp current_price(%Auction{current_price: nil} = auction), do: auction.initial_price
  defp current_price(%Auction{current_price: price}), do: price

  defp format_error(%Ecto.Changeset{} = changeset) do
    Enum.map_join(changeset.errors, "\n", fn {field, {msg, _}} -> "#{field}: #{msg}" end)
  end

  defp format_error(msg), do: msg

  defp finish_auction(socket, winner) do
    socket
    |> assign(:auction_finished, true)
    |> assign(:winner, winner)
  end

  # Template Components
  defp auction_container(assigns) do
    ~H"""
    <div class={"container mx-auto px-4 py-8 #{if @auction_finished, do: "pointer-events-none"}"}>
      <div class={"relative #{if @auction_finished, do: "blur-sm"}"}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp auction_details(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row gap-12">
      <div class="md:w-1/2">
        <img src={@auction.photo_url} alt={@auction.title} class="w-full h-auto rounded-lg shadow-lg" />
        <h1 class="text-3xl font-bold mt-4 mb-2"><%= @auction.title %></h1>
      </div>
      <div class="md:w-1/2 flex flex-col justify-between">
        <.current_bid_section current_price={current_price(@auction)} />
        <div class="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 class="text-xl font-semibold mb-2">Auction Details</h2>
          <p class="text-gray-700">
            End Date: <%= format_date(@auction.end_date, @user_timezone) %>
          </p>
          <p class="text-gray-700 text-2xl font-bold">
            <%= if @time_left do %>
              Time remaining: <%= format_time(@time_left) %>
            <% else %>
              Getting time...
            <% end %>
          </p>
        </div>
        <.description_section :if={@auction.description} description={@auction.description} />
      </div>
    </div>
    """
  end

  defp current_bid_section(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <h2 class="text-xl font-semibold mb-2">Current Bid</h2>
      <p id="current_price" class="text-3xl font-bold text-green-600">
        $<%= @current_price %>
      </p>
    </div>
    """
  end

  defp description_section(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <h2 class="text-xl font-semibold mb-2">Description</h2>
      <p class="text-gray-700 line-clamp-3"><%= @description %></p>
    </div>
    """
  end

  defp bidding_form(assigns) do
    ~H"""
    <div class="flex justify-center w-full">
      <div class="mt-6 flex flex-col gap-y-2 w-[60%]">
        <.simple_form
          for={@form}
          phx-submit={
            JS.dispatch("app:optimistic_bid_update", to: "#current_price")
            |> JS.push("place_bid")
          }
        >
          <.input id="bid_input" field={@form[:amount]} type="number" min={@auction.current_price} />
          <:actions>
            <.button disabled={@auction_finished} phx-disable-with="Placing bid..." class="w-full">
              Place bid
            </.button>
          </:actions>

          <p :if={@bid_error} class="text-red-500"><%= format_error(@bid_error) %></p>
        </.simple_form>
      </div>
    </div>
    """
  end

  defp auction_finished_overlay(assigns) do
    ~H"""
    <%= if @auction_finished do %>
      <div class="absolute inset-0 flex items-center justify-center">
        <div class="bg-white p-8 rounded-lg shadow-lg text-center">
          <h2 class="text-2xl font-bold mb-4">Auction Finished!</h2>
          <%= if @winner do %>
            <p class="text-xl">The winner is: <%= @winner.email %></p>
            <p class="text-lg mt-2">Winning bid: $<%= @auction.current_price %></p>
          <% else %>
            <p class="text-xl">No bids were placed on this auction.</p>
          <% end %>

          <.link patch={~p"/explore"}>
            <.button class="mt-4">View other auctions</.button>
          </.link>
        </div>
      </div>
    <% end %>
    """
  end
end
