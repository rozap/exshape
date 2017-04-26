defmodule Exshape do
  @moduledoc """
    This module just contains a helper function for working wtih zip
    archives. If you have a stream of bytes that you want to parse
    directly, use the Shp or Dbf modules to parse.
  """
  alias Exshape.{Dbf, Shp}

  defp open_shp(c, size), do: File.stream!(c, [], size) |> Shp.read
  defp open_dbf(c, size), do: File.stream!(c, [], size) |> Dbf.read

  defp zip(nil, nil, _), do: []
  defp zip(nil, d, size), do: open_dbf(d, size)
  defp zip(s, nil, size), do: open_shp(s, size)
  defp zip(s, d, size), do: Stream.zip(open_shp(s, size), open_dbf(d, size))

  defp projection(nil), do: nil
  defp projection(prj), do: File.read!(prj)

  @doc """
    Given a zip file path, unzip it and open streams for the underlying
    shape data.

    Returns a list of all the layers, where each layer is a tuple of layer name,
    projection, and the stream of features

    By default this unzips to `/tmp/exshape_#{some_uuid}`. Make sure
    to clean up when you're done consuming the stream. Pass the `:working_dir`
    option to change this destination.

    By default this reads in 1024 * 512 byte chunks. Pass the `:read_size`
    option to change this.

    ```
    [{layer_name, projection, feature_stream}] = Exshape.from_zip("single_layer.zip")
    ```
  """
  @type projection :: String.t
  @type layer_name :: String.t
  @type layer :: {layer_name, projection, Stream.t}
  @spec from_zip(String.t) :: [layer]
  def from_zip(path, opts \\ []) do

    cwd = Keyword.get(opts, :working_dir, '/tmp/exshape_#{UUID.uuid4}')
    size = Keyword.get(opts, :read_size, 1024 * 512)
    File.mkdir_p!(cwd)
    with {:ok, files} <- :zip.extract(to_charlist(path), cwd: cwd) do
      files
      |> Enum.group_by(&Path.rootname/1)
      |> Enum.flat_map(fn {root, components} ->
        prj = projection(Enum.find(components, fn c -> Path.extname(c) == ".prj" end))
        shp = Enum.find(components, fn c -> Path.extname(c) == ".shp" end)
        dbf = Enum.find(components, fn c -> Path.extname(c) == ".dbf" end)

        if !is_nil(shp) && !is_nil(dbf) do
          stream = zip(shp, dbf, size)
          [{Path.basename(root), prj, stream}]
        else
          []
        end
      end)
    end
  end
end
