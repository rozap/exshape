defmodule Exshape do
  @moduledoc """
    This module just contains a helper function for working wtih zip
    archives. If you have a stream of bytes that you want to parse
    directly, use the Shp or Dbf modules to parse.
  """
  alias Exshape.{Dbf, Shp}

  defp open_file(c, size), do: File.stream!(c, [], size)

  defp zip(nil, nil), do: []
  defp zip(nil, d), do: Dbf.read(d)
  defp zip(s, nil), do: Shp.read(s)
  defp zip(s, d), do: Stream.zip(Shp.read(s), Dbf.read(d))

  defp unzip!(path, cwd, false), do: :zip.extract(to_charlist(path), cwd: cwd)
  defp unzip!(path, cwd, true) do
    {_, 0} = System.cmd("unzip", [path, "-d", to_string(cwd)])
  end

  def keep_file?({:zip_file, charlist, _, _, _, _}) do
    filename = :binary.list_to_bin(charlist)
    not String.starts_with?(filename, "__MACOSX") and not String.starts_with?(filename, ".")
  end
  def keep_file?(_), do: false

  defmodule Filesystem do
    @moduledoc """
      An abstraction over a filesystem.  The `list` field contains
      a function that returns a list of filenames, and the `stream`
      function takes one of those filenames and returns a stream of
      binaries.
    """

    @enforce_keys [:list, :stream]
    defstruct @enforce_keys
  end

  @doc """
    Given a zip file path, unzip it and open streams for the underlying
    shape data.

    Returns a list of all the layers, where each layer is a tuple of layer name,
    projection, and the stream of features

    By default this unzips to `/tmp/exshape_some_uuid`. Make sure
    to clean up when you're done consuming the stream. Pass the `:working_dir`
    option to change this destination.

    By default this reads in 1024 * 512 byte chunks. Pass the `:read_size`
    option to change this.

    By default this shells out to the `unzip` system cmd, to use the built in erlang
    one, pass `unzip_shell: true`. The default behavior is to use the system one because
    the erlang one tends to not support as many formats.

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
    size = Keyword.get(opts, :read_size, 1024 * 1024)

    with {:ok, files} <- :zip.table(String.to_charlist(path)) do
      from_filesystem(
        %Filesystem{
          list: fn -> files end,
          stream: fn file ->
            if !File.exists?(Path.join(cwd, file)) do
              File.mkdir_p!(cwd)
              unzip!(path, cwd, Keyword.get(opts, :unzip_shell, true))
            end
            open_file(Path.join(cwd, file), size)
          end
        })
    end
  end

  @spec from_filesystem(Filesystem.t) :: [layer]
  def from_filesystem(fs) do
    filenames = fs.list.()
    |> Enum.filter(&keep_file?/1)
    |> Enum.map(fn {:zip_file, filename, _, _, _, _} -> filename end)

    filenames
    |> Enum.group_by(&Path.rootname/1)
    |> Enum.flat_map(fn {root, components} ->
      prj = Enum.find(components, fn c -> extension_equals(c, ".prj") end)
      shp = Enum.find(components, fn c -> extension_equals(c, ".shp") end)
      dbf = Enum.find(components, fn c -> extension_equals(c, ".dbf") end)
      prj = fallback_to_only_prj(prj, filenames)

      if !is_nil(shp) && !is_nil(dbf) do
        [{
          root,
          List.to_string(shp),
          List.to_string(dbf),
          prj && List.to_string(prj)
          }]
      else
        []
      end
    end)
    |> Enum.map(fn {root, shp, dbf, prj} ->
      prj_contents = prj && (fs.stream.(prj) |> Enum.join)

      # zip up the unzipped shp and dbf components
      stream = zip(
        shp && fs.stream.(shp),
        dbf && fs.stream.(dbf)
      )

      {Path.basename(root), prj_contents, stream}
    end)
  end

  # shapefile spec unclear about .prj file naming-- in the wild some files do not have matching names
  # so if there's only one present, assume that's the one they want
  defp fallback_to_only_prj(nil, filenames) do
    case Enum.filter(filenames, fn f -> extension_equals(f, ".prj") end) do
      [only_prj] -> only_prj
      _ -> nil
    end
  end
  defp fallback_to_only_prj(found_prj, _), do: found_prj



  defp extension_equals(path, wanted_ext) do
    case Path.extname(path) do
      nil -> false
      ext -> String.downcase(ext) == wanted_ext
    end
  end

end
