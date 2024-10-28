defmodule Vista.Realtime do
  defmacro __using__(topic \\ :pub_sub) do
    quote bind_quoted: [topic: Atom.to_string(topic)] do
      @topic topic

      @doc """
      Subscribe to the #{topic} topic.
      """
      def subscribe do
        Phoenix.PubSub.subscribe(Vista.PubSub, @topic)
      end

      defp broadcast({:ok, payload}, event) do
        Phoenix.PubSub.broadcast(Vista.PubSub, @topic, {event, payload})
        {:ok, payload}
      end

      defp broadcast({:error, _reason} = error, _event), do: error

      defp broadcast(payload, event) do
        Phoenix.PubSub.broadcast(Vista.PubSub, @topic, {event, payload})
        payload
      end
    end
  end
end
