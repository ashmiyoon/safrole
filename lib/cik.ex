defmodule Safrole.Cik do
  @spec download_ticker_txt() :: {:ok, String.t()} | {:error, any()}
  def download_ticker_txt() do
    ticker_txt_url = "https://www.sec.gov/include/ticker.txt"
    with {:ok, response} <- HTTPoison.get(ticker_txt_url),
         200 <- response.status_code,
         txt <- response.body
    do
      {:ok, txt}
    else
      err -> {:err, err}
    end
  end

  @spec txt_to_maps(String.t()) :: {:ok, list(map())} | {:error, any()}
  def txt_to_maps(raw_txt) when is_binary(raw_txt) do
    ticker_cik_maps =
      raw_txt
      |> String.split("\n")
      |> Enum.map(fn line ->
        [raw_ticker, raw_cik] = String.split(line, "\t")
        %{ticker: String.upcase(raw_ticker), cik: raw_cik}
      end)
    {:ok, ticker_cik_maps}
  rescue
    err -> {:error, err}
  end
end
