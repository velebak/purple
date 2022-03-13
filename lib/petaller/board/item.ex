defmodule Petaller.Board.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :description, :string
    field :priority, :integer, default: 3
    field :completed_at, :naive_datetime
    field :is_pinned, :boolean, default: false

    has_many :entries, Petaller.Board.ItemEntry
    # 
    many_to_many :tags, Petaller.Board.Tag, join_through: Petaller.Board.ItemTag

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :description,
      :priority,
      :completed_at,
      :is_pinned
    ])
    |> validate_required([
      :description,
      :priority
    ])
  end
end