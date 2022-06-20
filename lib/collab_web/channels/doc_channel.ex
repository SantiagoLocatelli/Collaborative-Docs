defmodule CollabWeb.DocChannel do
  use CollabWeb, :channel
  alias Collab.Document
  require Logger

  @impl true
  def join("doc:" <> id, %{"key" => key}, socket) do
    func = case Collab.Repo.get_by(Collab.Doc, name: id) do
      nil -> &Document.new/2
      _doc -> &Document.open/2
    end

    case func.(id, key) do
      {:error, desc} ->
        Logger.error(inspect(desc))
        {:error, desc}

      {:ok, _pid} ->
        socket = assign(socket, :id, id)
        socket = assign(socket, :key, key)
        send(self(), :after_join)
        {:ok, socket}
    end

  end

  @impl true
  def handle_info(:after_join, socket) do
    response = Document.get_contents(socket.assigns.id, socket.assigns.key)

    push(socket, "open", response)

    {:noreply, socket}
  end

  @impl true
  def handle_in("save", %{}, socket) do
    response = Document.save(socket.assigns.id, socket.assigns.key)
    {:reply, response, socket}
  end

  @impl true
  def handle_in(
        "update",
        %{"change" => change, "version" => version},
        socket
      ) do
    case Document.update(socket.assigns.id, change, version, socket.assigns.key) do
      {:ok, response} ->
        # Process.sleep(1000)
        broadcast_from!(socket, "update", response)
        {:reply, :ok, socket}

      error ->
        Logger.error(inspect(error))
        {:reply, {:error, inspect(error)}, socket}
    end
  end

  @impl true
  def handle_in(
        "get_users_permissions",
        %{},
        socket
      ) do
    response = Document.get_users_permissions(socket.assigns.id, socket.assigns.key)
    {:reply, response, socket}
  end
end
