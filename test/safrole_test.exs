defmodule SafroleTest do
  use ExUnit.Case
  doctest Safrole

  test "greets the world" do
    assert Safrole.hello() == :world
  end

  test "creates stock info map" do
    {:ok, ticker_txt} = Safrole.Cik.download_ticker_txt()
    stock_info_map = Safrole.Cik.txt_to_stock_infos(ticker_txt)
    IO.inspect stock_info_map
  end
end
