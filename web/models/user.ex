defmodule CodeCorps.User do
  @moduledoc """
  This module defines a user of the Code Corps app.
  """

  use CodeCorps.Web, :model

  alias CodeCorps.SluggedRoute
  alias Comeonin.Bcrypt
  alias Ecto.Changeset

  import CodeCorps.Validators.SlugValidator

  schema "users" do
    field :biography, :string
    field :encrypted_password, :string
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :password, :string, virtual: true
    field :twitter, :string
    field :username, :string
    field :website, :string

    has_one :slugged_route, SluggedRoute

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
  end

  @doc """
  Builds a changeset for registering the user.
  """
  def registration_changeset(struct, params) do
    struct
    |> changeset(params)
    |> cast(params, [:password, :username])
    |> validate_required(:password)
    |> validate_required(:username)
    |> validate_length(:password, min: 6)
    |> validate_length(:username, min: 1, max: 39)
    |> validate_slug(:username)
    |> put_pass_hash()
    |> put_slugged_route()
  end

  def update_changeset(struct, params) do
    struct
    |> changeset(params)
    |> cast(params, [:first_name, :last_name, :twitter, :biography, :website])
    |> prefix_url(:website)
    |> validate_format(:website, ~r/\A((http|https):\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}(([0-9]{1,5})?\/.*)?#=\z/ix)
    |> validate_format(:twitter, ~r/\A[a-zA-Z0-9_]{1,15}\z/)
  end

  def check_email_availability(email) do
    %{}
    |> check_email_valid(email)
    |> check_used(:email, email)
  end

  def check_username_availability(username) do
    %{}
    |> check_username_valid(username)
    |> check_used(:username, username)
  end

  defp put_pass_hash(changeset) do
    case changeset do
      %Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :encrypted_password, Bcrypt.hashpwsalt(pass))
      _ ->
        changeset
    end
  end

  defp put_slugged_route(changeset) do
    case changeset do
      %Changeset{valid?: true, changes: %{username: username}} ->
        slugged_route_changeset = SluggedRoute.changeset(%SluggedRoute{}, %{slug: username})
        put_assoc(changeset, :slugged_route, slugged_route_changeset)
      _ ->
        changeset
    end
  end

  defp prefix_url(changeset, key) do
    changeset
    |> update_change(key, &do_prefix_url/1)
  end
  defp do_prefix_url(nil), do: nil
  defp do_prefix_url("http://" <> rest), do: "http://" <> rest
  defp do_prefix_url("https://" <> rest), do: "https://" <> rest
  defp do_prefix_url(value), do: "http://" <> value

  defp check_email_valid(struct, email) do
    struct
    |> Map.put(:valid, String.match?(email, ~r/@/))
  end

  defp check_username_valid(struct, username) do
    valid =
      username
      |> String.length
      |> in_range?(1, 39)

    struct
    |> Map.put(:valid, valid)
  end

  defp in_range?(number, min, max), do: number in min..max

  defp check_used(struct, column, value) do
    available =
      CodeCorps.User
      |> where([u], field(u, ^column) == ^value)
      |> CodeCorps.Repo.all
      |> Enum.empty?

    struct
    |> Map.put(:available, available)
  end
end
