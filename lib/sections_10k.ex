defmodule Sections10k do
  @moduledoc """
  This module can extract all sections from a 10-K `Filing`.

  **WARNING:** Directly copy-pasted from old Elixir project. Documentation might not be relevant to current project.

  ### Technical concerns
  - It's not completely certain if each "pHTML" will contain our links.
  - However, since each `<TEXT>` tag is a *complete* SEC document, we're
      just assuming that this is the case.
  - We might want to include methods to extract exhibits!
  """

  @doc """
  This function searches through all table rows, searches for a `<td>` that
  contains a Regex-match, and returns the href from the first `<a>` in our row.

  ### Algorithm
  - Find every `<tr>`, filter out rows without `<a>` links or `<td>`-matches
  - Call these `<a>`-containing, `<td>`-containing rows "linkrows"
  - Get first matching row
  - Find the first `<a>` node in the row, Pull out `href` value.
  """

  @spec extract_by_regex(Floki.html_tree() | String.t(), Regex.t())
        :: {:ok, String.t()} | {:error, atom()}

  def extract_by_regex(html_str, regex) when is_binary(html_str) do
    {status, result} = Floki.parse_document(html_str)

    case status do
      :ok ->
        extract_by_regex(result, regex)

      :error ->
        {:error, result}
    end
  end

  def extract_by_regex(html_tree, regex) when is_list(html_tree) do
    # Find all rows that contain <a> tags --> "linkrows"
    all_linkrows =
      html_tree
      |> Floki.find("tr")
      |> Enum.reject(fn row -> Floki.find(row, "a") == [] end)

    start_href =
      all_linkrows
      |> first_matching_linkrow(regex)
      |> href_from_linkrow()

    fnish_href =
      all_linkrows
      |> first_different_linkrow(regex)
      |> href_from_linkrow()

    case {start_href, fnish_href} do
      {nil, _} ->
        {:error, :nofind_start_id}

      {_, nil} ->
        {:error, :nofind_fnish_id}

      {x, y} ->
        # Chop off `#`
        start_id = String.slice(x, 1..-1)
        fnish_id = String.slice(y, 1..-1)

        {:ok, html_tree |> HtmlGrabber.grab_between(start_id, fnish_id)}
    end
  end

  @doc """
  Returns the first linkrow that matches a regex
  """
  @spec first_matching_linkrow(
          all_linkrows :: [Floki.html_node()],
          regex :: Regex.t()
        ) ::
          Floki.html_node() | nil
  def first_matching_linkrow(all_linkrows, regex) do
    all_linkrows
    |> Enum.filter(&row_has_match?(&1, regex))
    |> List.first()
  end

  @doc """
  Returns the first linkrow that *doesn't* match regex
  """
  @spec first_different_linkrow(
          linkrows :: list(Floki.html_node()),
          regex :: Regex.t(),
          found_match? :: boolean()
        ) ::
          Floki.html_node() | nil
  def first_different_linkrow(linkrows, regex, found_match? \\ false)

  # Error: Could not find href in any row
  def first_different_linkrow([], _regex, _found_match?), do: nil

  # Go through linkrows until we find match
  def first_different_linkrow([current_row | rest], regex, found_match?)
      when found_match? == false do
    found_match? = row_has_match?(current_row, regex)
    first_different_linkrow(rest, regex, found_match?)
  end

  # After we've found a match, loop until we find linkrow that doesn't match
  def first_different_linkrow([current_row | rest], regex, found_match?)
      when found_match? == true do
    if row_has_match?(current_row, regex) do
      first_different_linkrow(rest, regex, _found_match? = true)
    else
      current_row
    end
  end

  # Gets whether or not linkrow has <td> entries that match regex
  @spec row_has_match?(Floki.html_node(), Regex.t()) :: boolean()
  defp row_has_match?(linkrow, regex) do
    matching_entries(linkrow, regex) != []
  end

  # Recursively searches through row node to find all <td>'s that match a regex.
  @spec matching_entries(Floki.html_node(), Regex.t()) ::
          list(Floki.html_node())
  def matching_entries(row_node, regex) do
    row_node
    |> Floki.find("td")
    |> Enum.filter(fn td_tag -> Regex.match?(regex, Floki.text(td_tag)) end)
  end

  # Searches through first <tr> (assumed to contain <a> links),
  #   finds the first `href` attribute.
  @spec href_from_linkrow(Floki.html_node()) :: binary() | nil
  defp href_from_linkrow(row_node) do
    # Find first <a> tag
    [first_link_node | _] = Floki.find(row_node, "a")

    first_link_node
    |> Floki.attribute("href")
    |> List.first()
  end
end
