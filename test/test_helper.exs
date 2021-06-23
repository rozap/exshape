defmodule TestHelper do
  def fixture(name) do
    File.stream!(Path.join([__DIR__, "fixtures", name]), [], 256)
  end

  def zip(name), do: "#{__DIR__}/fixtures/#{name}.zip"
  def shp(name), do: "#{__DIR__}/fixtures/#{name}.shp"
end
ExUnit.start()
