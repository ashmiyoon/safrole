defmodule Safrole.Cik do
  @spec download_ticker_txt() :: {atom(), String.t()}
  def download_ticker_txt() do
    ticker_txt_url = "https://www.sec.gov/include/ticker.txt"
    with {:ok, response} <- HTTPoison.get(ticker_txt_url),
         200 <- response.status_code,
         txt <- response.body
    do
      {:ok, txt}
    else
      err -> {:err, inspect(err)}
    end
  end

  def txt_to_stock_infos(raw_txt) do
    lines = String.split(raw_txt, "\n")
    lines
    |> Enum.map(fn line ->
      with [raw_ticker, raw_cik] <- String.split(line, "\t"),
           stock_info <- %{ticker: String.upcase(raw_ticker), cik: raw_cik}
      do
        {:ok, stock_info}
      else
        err -> {:error, err}
      end
    end)
  end
end
