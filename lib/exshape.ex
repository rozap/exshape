defmodule Exshape do
  @moduledoc """
  """
  alias Exshape.{Dbf, Shp}

  defp open_shp(c), do: File.stream!(c) |> Shp.read
  defp open_dbf(c), do: File.stream!(c) |> Dbf.read

  defp zip(nil, nil), do: []
  defp zip(nil, d), do: open_dbf(d)
  defp zip(s, nil), do: open_shp(s)
  defp zip(s, d), do: Stream.zip(open_shp(s), open_dbf(d))

  defp projection(nil), do: nil
  defp projection(prj), do: File.read!(prj)

  def from_zip(path) do
    cwd = '/tmp/#{UUID.uuid4}'
    File.mkdir_p!(cwd)
    with {:ok, files} <- :zip.extract(to_charlist(path), cwd: cwd) do
      files
      |> Enum.group_by(&Path.rootname/1)
      |> Enum.map(fn {root, components} ->

        stream = zip(
          Enum.find(components, fn c -> Path.extname(c) == ".shp" end),
          Enum.find(components, fn c -> Path.extname(c) == ".dbf" end)
        )

        prj = projection(Enum.find(components, fn c -> Path.extname(c) == ".prj" end))

        {Path.basename(root), {prj, stream}}
      end)
    end
  end
end
