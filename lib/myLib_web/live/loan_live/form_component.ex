defmodule MyLibWeb.LoanLive.FormComponent do
  use MyLibWeb, :live_component

  alias MyLib.Library
  alias MyLib.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage loan records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="loan-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:user_id]} type="select" label="User" options={users_for_select()} />
        <.input field={@form[:book_id]} type="select" label="Book" options={books_for_select()} />
        <.input field={@form[:borrowed_at]} type="datetime-local" label="Borrowed at" />
        <.input field={@form[:due_at]} type="datetime-local" label="Due at" />
        <.input field={@form[:returned_at]} type="datetime-local" label="Returned at" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Loan</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{loan: loan} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Library.change_loan(loan))
     end)}
  end

  @impl true
  def handle_event("validate", %{"loan" => loan_params}, socket) do
    changeset = Library.change_loan(socket.assigns.loan, loan_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"loan" => loan_params}, socket) do
    save_loan(socket, socket.assigns.action, loan_params)
  end

  defp save_loan(socket, :edit, loan_params) do
    case Library.update_loan(socket.assigns.loan, loan_params) do
      {:ok, loan} ->
        notify_parent({:saved, loan})

        {:noreply,
         socket
         |> put_flash(:info, "Loan updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_loan(socket, :new, loan_params) do
    case Library.create_loan(loan_params) do
      {:ok, loan} ->
        notify_parent({:saved, loan})

        {:noreply,
         socket
         |> put_flash(:info, "Loan created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp users_for_select do
    users = Accounts.list_users()

    Enum.map(users, fn user ->
      {user.name, user.id}
    end)
  end

  defp books_for_select do
    books = Library.list_books()

    Enum.map(books, fn book ->
      {book.title, book.id}
    end)
  end
end
