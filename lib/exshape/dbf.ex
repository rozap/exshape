defmodule Exshape.Dbf do

  defmodule Header do
    defstruct [:last_updated,
      :record_count,
      :header_byte_count,
      :record_byte_count,
      columns: []]
  end

  defmodule Column do
    defstruct [:name, :field_type, :field_length]
  end

  defmodule State do
    defstruct mode: :header,
      emit: [],
      item: [],
      header: %Header{}
  end

  defp mode(s, m), do: %{s | mode: m}
  defp header(s, u), do: %{s | header: struct(s.header, u)}
  defp emit(s, %Header{} = header), do: %{s | emit: [%{header | columns: Enum.reverse(header.columns)} | s.emit], item: []}
  defp emit(s, thing), do: %{s | emit: [munge_row(s.header.columns, thing) | s.emit], item: []}
  defp add_column(s, c), do: %{s | header: %{s.header | columns: [c | s.header.columns]}}


  # This is ~2x faster than doing regex stuff and about ~3x faster than using
  # the functions in the stdlib
  defp do_trim_trailing(o, " " <> s, i, l), do: do_trim_trailing(o, s, i + 1, l)
  defp do_trim_trailing(o, <<_::binary-size(1), rest::binary>>, i, _), do: do_trim_trailing(o, rest, i + 1, i + 1)
  defp do_trim_trailing(o, _, i, i), do: o
  defp do_trim_trailing(o, _, _, l), do: :binary.part(o, {0, l})

  def trim_trailing(s), do: do_trim_trailing(s, s, 0, 0)

  defp trim_leading(" " <> s), do: trim_leading(s)
  defp trim_leading(s), do: s

  # defp trim(s), do: s |> trim_leading |> trim_trailing

  defp munge_row(columns, row) do
    columns
    |> Enum.zip(row)
    |> Enum.map(fn {c, datum} ->
      {c.name, munge(c.field_type, datum)}
    end)
    |> Enum.into(%{})
  end

  defp munge(:character, datum), do: datum
  defp munge(:date, <<
    year::binary-size(4),
    month::binary-size(2),
    day::binary-size(2)
  >>) do

    with {y, _} <- Integer.parse(year),
      {m, _} <- Integer.parse(month),
      {d, _} <- Integer.parse(day) do
      case Date.from_erl({y, m, d}) do
        {:error, :invalid_date} -> nil
        {:ok, d} -> d
      end
    else
      _ -> nil
    end
  end
  defp munge(:float, datum) do
    case trim_leading(datum) do
      "" -> nil
      t  ->
        case Float.parse(t) do
          {f, _} -> f
          :error -> nil
        end
    end
 end
  defp munge(:boolean, "T"), do: true
  defp munge(:boolean, "F"), do: false
  defp munge(:boolean, "?"), do: false
  defp munge(:numeric, datum) do
    case trim_leading(datum) do
      "" -> nil
      t  ->
        case Integer.parse(t) do
          {i, _} -> i
          :error -> nil
        end
    end
  end
  defp munge(:memo, d), do: d

  @types [
    {"C", :character},
    {"D", :date},
    {"F", :float},
    {"L", :boolean},
    {"M", :memo},
    {"N", :numeric}
  ]
  Enum.each(@types, fn {c, t} ->
    def typeof(unquote(c)), do: unquote(t)
  end)

  defp next_column(%{mode: {:row, _, [c | rest]}} = s) do
    mode(s, {:row, c.field_length, rest})
  end
  defp next_column(s) do
    [c | rest] = s.header.columns
    s = mode(s, {:row, c.field_length, rest})
    case s.item do
      [] -> s
      _ ->
        s
        |> emit(Enum.reverse(s.item))
        |> mode(:pre_row)
    end
  end
  defp put_datum(s, value), do: %{s | item: [value | s.item]}

  defp do_read(%State{mode: :header} = s, <<
    _::little-integer-size(8),
    year::little-integer-size(8),
    month::little-integer-size(8),
    day::little-integer-size(8),
    record_count::little-integer-size(32),
    header_byte_count::little-integer-size(16),
    record_byte_count::little-integer-size(16),
    _::size(16),
    _failed_transaction::size(8),
    _encrypted::size(8),
    _dos_stuff::size(96),
    _mdx::size(8),
    _lang_driver::size(8),
    _::size(16),
    rest::binary
  >>) do

    s
    |> mode(:column)
    |> header(%{
      last_updated: {1900 + year, month, day},
      record_count: record_count,
      header_byte_count: header_byte_count,
      record_byte_count: record_byte_count
    })
    |> do_read(rest)
  end

  defp do_read(%State{mode: :column} = s, <<
    13::little-integer-size(8),
    rest::binary
  >>) do
    header = %{s.header | columns: Enum.reverse(s.header.columns)}

    %{s | header: header}
    |> mode(:pre_row)
    |> emit(s.header)
    |> do_read(rest)
  end

  defp do_read(%State{mode: :column} = s, <<
    name::binary-size(11),
    field_type::binary-size(1),
    _reserved::binary-size(4),
    field_length::little-integer-size(8),
    _decimal_count::little-integer-size(8),
    _work_area::little-integer-size(16),
    _example::binary-size(1),
    _more_reserved::binary-size(10),
    _mdx::binary-size(1),
    rest::binary
  >>) do
    name = name
    |> :binary.bin_to_list
    |> Enum.filter(fn n -> n > 0 end)
    |> to_string

    s
    |> add_column(%Column{
      name: name,
      field_type: typeof(field_type),
      field_length: field_length
    })
    |> do_read(rest)
  end

  defp do_read(%State{mode: :pre_row} = s, <<
    32::little-integer-size(8),
    rest::binary
  >>) do
    s
    |> next_column()
    |> do_read(rest)
  end

  # defp do_read(%State{mode: :pre_row} = s, <<
  #   26::little-integer-size(8),
  #   _
  # >>) do
  #   mode(s, :done)
  #   |> IO.inspect
  # end

  defp do_read(%State{mode: {:row, len, _}} = s, bin) do
    case bin do
      <<value::binary-size(len), rest::binary>> ->
        s
        |> put_datum(value)
        |> next_column()
        |> do_read(rest)
      _ ->
        {bin, s}
    end
  end

  defp do_read(%State{} = s, <<rest::binary>>), do: {rest, s}

  @doc """
    Read a DBF from a byte stream

    Example

    ```
    File.stream!("rivers.dbf", [], 2048)
    |> Exshape.Dbf.read
    |> Stream.each(&IO.inspect/1)
    |> Stream.run
    ```

  """
  def read(byte_stream) do
    Stream.transform(byte_stream, {<<>>, %State{}}, fn bin, {buf, state} ->
      case do_read(state, buf <> bin) do
        {_, %State{mode: :done}} = s ->
          {:halt, s}
        {buf, %State{emit: emit} = s} ->
          {Enum.reverse(emit), {buf, %{s | emit: []}}}
      end
    end)
  end

end
