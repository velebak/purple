defmodule Purple.Markdown do
  @moduledoc """
  Functions for parsing and manipulating markdown
  """
  @valid_tag_parents ["p", "li", "h1", "h2", "h3", "h4"]

  def checkbox_pattern, do: ~r/^x /

  def extract_eligible_tag_text_from_ast(ast) when is_list(ast) do
    {_, result} =
      Earmark.Transform.map_ast_with(
        ast,
        [],
        fn
          {tag, _, children, _} = node, result when tag in @valid_tag_parents ->
            {
              node,
              Enum.reduce(children, result, fn
                text_leaf, acc when is_binary(text_leaf) -> [text_leaf] ++ acc
                _, acc -> acc
              end)
            }

          node, result ->
            {node, result}
        end,
        true
      )

    result
  end

  def extract_eligible_tag_text_from_markdown(md) when is_binary(md) do
    case EarmarkParser.as_ast(md) do
      {:ok, ast, _} -> extract_eligible_tag_text_from_ast(ast)
      _ -> []
    end
  end

  def extract_checkboxes_from_markdown(md) when is_binary(md) do
    []
  end

  def make_checkbox_node(checkbox_map) do
    {"input",
     [
       {"type", "checkbox"},
       {"class", "markdown-checkbox"}
     ], [], %{}}
  end

  def make_tag_link_node(get_tag_link, tagname) do
    {"a",
     [
       {"class", "tag"},
       {"href", get_tag_link.(tagname)}
     ], ["#" <> tagname], %{}}
  end

  def render_tag_links(text_leaf, %{get_tag_link: get_tag_link}) when is_binary(text_leaf) do
    Enum.map(
      Regex.split(
        Purple.Tags.tag_pattern(),
        text_leaf,
        include_captures: true
      ),
      fn text ->
        if String.starts_with?(text, "#") do
          make_tag_link_node(get_tag_link, String.trim_leading(text, "#"))
        else
          text
        end
      end
    )
  end

  def render_checkbox(text_leaf, %{checkbox_map: checkbox_map}) when is_binary(text_leaf) do
    Enum.map(
      Regex.split(
        checkbox_pattern(),
        text_leaf,
        include_captures: true
      ),
      fn text ->
        if Regex.match?(checkbox_pattern(), text) do
          make_checkbox_node(checkbox_map)
        else
          text
        end
      end
    )
  end

  def make_link(node) do
    case Earmark.AstTools.find_att_in_node(node, "href") do
      <<?/, _::binary>> ->
        Earmark.AstTools.merge_atts_in_node(node, class: "internal")

      _ ->
        Earmark.AstTools.merge_atts_in_node(node, class: "external", target: "_blank")
    end
  end

  def get_valid_extensions(html_tag \\ "", children \\ []) do
    %{
      checkbox:
        html_tag == "li" and
          case children do
            [text_leaf] when is_binary(text_leaf) ->
              String.length(text_leaf) >= 3

            _ ->
              true
          end,
      tag_link: html_tag in @valid_tag_parents
    }
  end

  def change_html_tag(html_tag) do
    case html_tag do
      "h1" -> "h2"
      "h2" -> "h3"
      "h3" -> "h4"
      _ -> html_tag
    end
  end

  @doc """
  Transforms a default earmark ast into a custom purple ast.
  """
  def map_purple_ast(ast, extension_data, valid_extensions) do
    Enum.map(ast, fn
      {"a", _, _, _} = node ->
        make_link(node)

      {html_tag, atts, children, m} ->
        new_tag = change_html_tag(html_tag)

        {
          new_tag,
          atts,
          map_purple_ast(children, extension_data, get_valid_extensions(new_tag, children)),
          m
        }

      text_leaf when is_binary(text_leaf) ->
        cond do
          valid_extensions.tag_link ->
            map_purple_ast(
              render_tag_links(text_leaf, extension_data),
              extension_data,
              Map.put(valid_extensions, :tag_link, false)
            )

          valid_extensions.checkbox ->
            map_purple_ast(
              render_checkbox(text_leaf, extension_data),
              extension_data,
              Map.put(valid_extensions, :checkbox, false)
            )

          true ->
            text_leaf
        end
    end)
  end

  defp set_default_extension_data(extension_data) when is_map(extension_data) do
    Map.merge(
      %{
        get_tag_link: &("/?tag=" <> &1),
        checkbox_map: %{}
      },
      extension_data
    )
  end

  def markdown_to_html(md, extension_data \\ %{}) do
    case EarmarkParser.as_ast(md) do
      {:ok, ast, _} ->
        Earmark.Transform.transform(
          map_purple_ast(
            ast,
            set_default_extension_data(extension_data),
            get_valid_extensions()
          )
        )

      _ ->
        md
    end
  end
end
