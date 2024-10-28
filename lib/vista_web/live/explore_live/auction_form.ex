defmodule VistaWeb.ExploreLive.AuctionForm do
  alias Vista.Auctions.Auction
  alias Vista.Auctions
  use VistaWeb, :live_component

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="create_auction_form"
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
      >
        <.input field={@form[:title]} label="Title" required />
        <.input type="textarea" field={@form[:description]} label="Description" />
        <.input field={@form[:initial_price]} label="Initial Price" required />
        <.input field={@form[:end_date]} type="datetime-local" label="End Date" required />

        <.live_file_input upload={@uploads.photo} required />

        <:actions>
          <.button phx-disable-with="Creating auction..." class="w-full">Create auction</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(Auctions.change_auction(%Auction{})) end)
     |> allow_upload(:photo, accept: ~w(.jpg .jpeg .png), max_entries: 1)}
  end

  @impl true
  def handle_event("validate", %{"auction" => auction_params}, socket) do
    changeset = Auctions.change_auction(%Auction{}, auction_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"auction" => auction_params}, socket) do
    current_user = socket.assigns.current_user
    utc_end_date = convert_date_to_utc(auction_params["end_date"], socket.assigns.user_timezone)

    auction_params
    |> Map.put("user_id", current_user.id)
    |> Map.put("photo_url", List.first(consume_photo(socket)))
    |> Map.put("end_date", utc_end_date)
    |> Auctions.create_auction()
    |> case do
      {:ok, _auction} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp consume_photo(socket) do
    consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
      dest = Path.join([:code.priv_dir(:vista), "static", "uploads", Path.basename(path)])
      File.cp!(path, dest)
      {:postpone, ~p"/uploads/#{Path.basename(dest)}"}
    end)
  end

  defp convert_date_to_utc(date, user_timezone) do
    # Ensure the datetime string includes seconds
    formatted_end_date =
      case String.split(date, "T") do
        [date, time] -> "#{date}T#{time}:00"
        _ -> date
      end

    with {:ok, naive_datetime} <- NaiveDateTime.from_iso8601(formatted_end_date),
         {:ok, local_dt} <- DateTime.from_naive(naive_datetime, user_timezone),
         {:ok, utc_dt} <- DateTime.shift_zone(local_dt, "Etc/UTC") do
      Logger.debug("Converted end_date to UTC: #{utc_dt}")

      utc_dt
    else
      error -> {:error, error}
    end
  end
end
