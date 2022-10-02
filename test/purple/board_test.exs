defmodule Purple.BoardTest do
  use Purple.DataCase
  alias Purple.Board.{ItemEntry}

  import Purple.Board
  import Purple.BoardFixtures

  describe "item and entry crud" do
    test "fixture is expected" do
      item = item_fixture()

      assert length(item.entries) > 0
      assert length(item.tags) > 0
      assert item.description != ""
      assert item.entries |> Enum.at(0) |> Map.get(:content) |> String.length() > 0
      assert item.tags |> Enum.at(0) |> Map.get(:name) |> String.length() > 0

      item = get_item!(item.id, :entries, :tags)
      assert length(item.entries) > 0
      assert length(item.tags) > 0

      [entry] = item.entries
      entry = Repo.preload(entry, :checkboxes)
      assert length(entry.checkboxes) > 0
    end

    test "create_item/1" do
      assert {:error, changeset} = create_item(%{})
      assert !changeset.valid?

      assert {:ok, item} = create_item(%{description: "test item!"})
      assert item.id > 0
      assert item.last_active_at != nil

      assert {:ok, item_with_children} =
               create_item(%{
                 description: "i have children 👶",
                 entries: [
                   %{content: "# entry!\n\n- x 1\n- x 2\n\n :)"},
                   %{content: "- x 1\n- x 2\n\n (dupe checkboxes are ok between siblings"}
                 ]
               })

      assert [entry1, entry2] = list_item_entries(item_with_children.id, :checkboxes)
      assert [%{description: "2"}, %{description: "1"}] = entry1.checkboxes
      assert [%{description: "2"}, %{description: "1"}] = entry2.checkboxes

      assert {:error, :rollback} =
               create_item(%{
                 description: "entry has dupe checkboxes",
                 entries: [
                   %{content: "# invalid entry!\n\n- x create item test \n- x create item test"}
                 ]
               })

      assert {:ok, item} = create_item(%{description: "info", status: :INFO})
      assert is_nil(item.priority)

      assert {:ok, item} = create_item(%{description: "create todo item", status: :TODO})
      assert is_integer(item.priority)
      assert item.priority > 0
    end

    test "update_item/2" do
      item = item_fixture()
      assert {:error, changeset} = update_item(item, %{description: ""})
      assert !changeset.valid?

      assert {:ok, info_item} =
               update_item(
                 item,
                 %{description: "info item", status: :INFO}
               )

      assert info_item.description == "info item"
      assert NaiveDateTime.compare(info_item.updated_at, item.updated_at) == :gt
      assert NaiveDateTime.compare(info_item.last_active_at, item.last_active_at) == :gt
      assert is_nil(info_item.priority)

      assert {:ok, done_item} =
               update_item(
                 info_item,
                 %{description: "done item", status: :DONE}
               )

      assert is_nil(done_item.priority)
      assert done_item.status == :DONE
      assert done_item.description == "done item"

      assert {:ok, todo_item} =
               update_item(
                 done_item,
                 %{description: "todo item", status: :TODO}
               )

      assert is_integer(todo_item.priority)
      assert todo_item.description == "todo item"
    end

    test "set_item_complete!/2" do
      item = item_fixture()
      complete_item = set_item_complete!(item, true)
      assert complete_item.status == :DONE
      assert complete_item.completed_at != nil
      assert is_nil(complete_item.priority)

      incomplete_item = set_item_complete!(complete_item, false)
      assert incomplete_item.status == :TODO
      assert incomplete_item.completed_at == nil
      assert NaiveDateTime.compare(incomplete_item.updated_at, item.updated_at) == :gt
      assert is_integer(incomplete_item.priority)
      assert incomplete_item.priority > 0
    end

    test "pin_item!/2" do
      item = item_fixture()

      pinned_item = pin_item!(item, true)
      assert pinned_item.is_pinned == true

      unpinned_item = pin_item!(pinned_item, false)
      assert unpinned_item.is_pinned == false
      assert NaiveDateTime.compare(unpinned_item.updated_at, item.updated_at) == :gt
    end

    test "toggle_show_item_files!/2" do
      item = item_fixture()

      updated_item = toggle_show_item_files!(item, false)
      assert updated_item.show_files == false

      updated_item = toggle_show_item_files!(item, true)
      assert updated_item.show_files == true
      assert NaiveDateTime.compare(updated_item.updated_at, item.updated_at)
    end

    test "create_item_entry/2" do
      assert {:error, changeset} = create_item_entry(%{}, 0)
      assert !changeset.valid?

      item = item_fixture()

      assert {:ok, entry} =
               create_item_entry(%{content: "# New Entry!!\n\n- x a checkbox!"}, item.id)

      assert %{checkboxes: [%{description: "a checkbox!"}]} = entry

      assert {:error, changeset} =
               create_item_entry(%{content: "# duplicate checkbox\n\n- x a\n- x a"}, item.id)

      assert !changeset.valid?
    end

    test "update_item_entry/2" do
      entry = entry_fixture()
      assert {:error, changeset} = update_item_entry(entry, %{content: ""})
      assert !changeset.valid?

      assert {:ok, %{checkboxes: [checkbox2, checkbox1]}} =
               update_item_entry(entry, %{content: "+ x checkbox1 \n+ x checkbox2"})

      assert checkbox1.description == "checkbox1"
      assert checkbox2.description == "checkbox2"

      assert {:ok, %{checkboxes: [new_checkbox, exists2, exists1]}} =
               update_item_entry(entry, %{
                 content: "+ x checkbox1 \n+ x checkbox2\n+ x checkbox 3️⃣! "
               })

      assert [entry] = list_item_entries(entry.item_id, :checkboxes)
      assert length(entry.checkboxes) == 3
      assert hd(entry.checkboxes).description != ""

      assert exists1.id == checkbox1.id
      assert exists2.id == checkbox2.id
      assert new_checkbox.description == "checkbox 3️⃣!"
      assert !exists1.is_done and !exists2.is_done and !new_checkbox.is_done

      assert {:error, changeset} =
               update_item_entry(entry, %{content: "+ x duplicate\n+ x duplicate"})

      assert !changeset.valid?
    end

    test "delete_entry/2" do
      entry = entry_fixture()
      delete_entry!(entry)
      assert Repo.get(ItemEntry, entry.id) == nil
    end
  end
end
