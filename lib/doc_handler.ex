defmodule Safrole.DocHandler do
  @moduledoc """
  In order to work with ASCII filings, we must convert them into a usable format.
  We have accounted for various flags that might be set by the user, including pretty-printing and (TODO) UTF-8 mode.
  """

  @doc """
  Takes in the raw text from an SEC filing's .txt file, moves all the contained HTML documents into a list, cleans the files, and "prettifies" them. If one step fails, then the generated string is the error's `inspect` output.
  """
  @spec process(String.t(), Keyword.t()) :: [String.t()]
  def process(filing_text, options \\ []) do
    # Flags for processing ASCII filing (just 1 for now)
    pretty? <- Keyword.get(options, :pretty, true)
    utf8? <- Keyword.get(options, :utf8, true)

    filing_text
    |> pullout_html_docs()
    |> Enum.map(fn raw_html ->
      with cleaned_html <- replace_junk(raw_html, sec_html_junk_jobs()),
           {:ok, pretty_html} <- prettify_html(cleaned_html, pretty?)
      do
        pretty_html
      else
        err -> inspect(err)
      end
    end)
  end

  @spec process(String.t()) :: [String.t()]
  def process(filing_text), do: process(filing_text, [])

  # Pretty-print the HTML text, using Floki to parse the HTML tree.
  defp prettify_html(html_text, run?)
  defp prettify_html(html_text, false), do: html_text
  defp prettify_html(html_text, true) do
    case Floki.parse_document(html_text) do
      {:ok, doc_tree} ->
        Floki.raw_html(doc_tree, pretty: true)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Each SEC .txt filing contains multiple <html> documents. This function extracts each of them into a list.
  """
  @spec pullout_html_docs(String.t()) :: list(String.t())
  def pullout_html_docs(raw_filing_text) when is_binary(raw_filing_text) do
    Regex.scan(~r/<html.*<\/html>/Us, raw_filing_text)
    |> Enum.map(fn [match | _no_captures] -> match end)
  end

  @doc """
  In order to "clean up" HTMLs for easier storage and processing, we must remove useless information like iXBRL tags, empty table entries, and CSS style attributes.
  """
  @spec replace_junk(
          html_text :: String.t(),
          junk_jobs :: list({Regex.t(), String.t()})
        ) ::
          String.t()
  def replace_junk(html_text, []), do: html_text
  def replace_junk(html_text, [current_job | remaining_jobs]) do
    {junk_pattern, replacement} = current_job
    String.replace(html_text, junk_pattern, replacement)
    |> replace_junk(remaining_jobs)
  end

  @spec sec_html_junk_jobs() :: list({Regex.t(), String.t()})
  defp sec_html_junk_jobs() do
    [
      # First, we remove the <ix:...> tags, which contain xbrli junk
      {~r/<ix:header>.*<\/ix:header>/sU, "<!-- Removed iXBRL header -->\n"},
      {~r/<ix:\w[^<>]*>/sU, "<!-- Removed iXBRL opening tag -->\n"},
      {~r/<\/ix:\w[^<>]*>/sU, "<!-- Removed iXBRL closing tag -->\n"},
      # Then, we remove all style attributes, which are a HUGE waste of space
      {~r/\sstyle=".*"/sU, ""},
      # Then, we remove all no-attribute tags containing only 1 HTML entity
      #   e.g. <p>&nbsp;</p>
      {~r/<\w+>&#\d+;<\/\w+>/sU, "<!-- Removed simple 1-entity (&#\\d+) tagset -->\n"},
      {~r/<\w+>&\d+;<\/\w+>/sU, "<!-- Removed simple 1-entity (&\\d+) tagset -->\n"},
      {~r/<\w+>&\w+;<\/\w+>/sU, "<!-- Removed simple 1-entity (&\\w+) tagset -->\n"},
      # Then, we remove all remaining no-attribute empty tag "sets"
      #   e.g. <p></p>
      {~r/<\w+>\s*<\/\w+>/sU, "<!-- Removed empty simple tagset -->\n"},
      {~r/<\w+>\s*<!--.*-->\s*<\/\w+>/sU,
       "<!-- Removed empty simple tagset (folded over comment) -->\n"},
      # Remove empty table entries
      {~r/<td\s[^<>]*">\s*<\/td>/sU, "<!-- Removed empty table entry -->\n"},
      {~r/<td\s[^<>]*">\s*<!--.*-->\s*<\/td>/sU,
       "<!-- Removed empty table entry (folded over comment) -->\n"},
      # Remove multiple newlines
      {~r/\n{2,}/sU, "<!-- Collapsed multiple newlines -->\n"}
    ]
  end
end
