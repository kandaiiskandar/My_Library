defmodule MyLibWeb.BookLive.Show do
  use MyLibWeb, :live_view

  alias MyLib.Library

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:book, Library.get_book!(id))}
  end

  defp page_title(:show), do: "Show Book"
  defp page_title(:edit), do: "Edit Book"
end
