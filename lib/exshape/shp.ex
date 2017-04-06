defmodule Exshape.Shp do
  defmodule State do
    defstruct mode: :header, shape_type: nil, emit: [], to_read: nil, item: nil
  end

  defmodule Bbox do
    defstruct [:xmin, :xmax, :ymin, :ymax, :zmin, :zmax, :mmin, :mmax]
  end

  defmodule Header do
    defstruct [:bbox, :shape_type]
  end

  defmodule Point do
    defstruct [:x, :y]
  end

  defmodule Multipoint do
    defstruct points: [], bbox: nil
  end

  defmodule Polyline do
    defstruct points: [], bbox: nil, parts: []
  end


  @file_code <<9994::big-integer-size(32)>>
  @unused <<0::big-integer-size(32)>>
  @version <<1000::little-integer-size(32)>>

  Enum.each([{0,  nil},
  {1, :point},
  {3, :polyline},
  {5, :polygon},
  {8, :multipoint},
  {11, :pointz},
  {13, :polylinez},
  {15, :polygonz},
  {18, :multipointz},
  {21, :pointm},
  {23, :polylinem},
  {25, :polygonm},
  {28, :multipointm},
  {31, :multipatchm}], fn {code, t} ->
    def shape_type_from_code(unquote(code)), do: unquote(t)
  end)

  defp emit(s, thing), do: %{s | emit: [thing | s.emit]}
  defp mode(s, m), do: %{s | mode: m}
  defp shape_type(s, st), do: %{s | shape_type: st}
  defp item(s, item), do: %{s | item: item}
  defp repeatedly(s, n), do: %{s | to_read: n}
  defp prepend(s, p, key) do
    %{s | item: Map.put(s.item, key, [p | Map.get(s.item, key)])}
  end
  defp consume_item(s), do: %{s | to_read: s.to_read - 1}
  defp emit_item(s), do: %{emit(s, s.item) | item: nil}
  defp reverse_item(s, key) do
    item = Map.put(s.item, key, Enum.reverse(Map.get(s.item, key)))
    %{s | item: item}
  end

  defp do_read(%State{mode: :header} = s, <<
    @file_code,
    @unused,
    @unused,
    @unused,
    @unused,
    @unused,
    file_len::big-integer-size(32),
    @version,
    type_code::little-integer-size(32),
    xmin::little-float-size(64),
    ymin::little-float-size(64),
    xmax::little-float-size(64),
    ymax::little-float-size(64),
    zmin::little-float-size(64),
    zmax::little-float-size(64),
    mmin::little-float-size(64),
    mmax::little-float-size(64),
    rest::binary
  >>) do
    box = %Bbox{
      xmin: xmin,
      xmax: xmax,
      ymin: ymin,
      ymax: ymax,
      zmin: zmin,
      zmax: zmax,
      mmin: mmin,
      mmax: mmax
    }
    st = shape_type_from_code(type_code)

    s
    |> emit(%Header{bbox: box, shape_type: st})
    |> mode(:record_header)
    |> shape_type(st)
    |> do_read(rest)
  end

  defp do_read(%State{mode: :record_header} = s, <<
    record_number::big-integer-size(32),
    content_length::big-integer-size(32),
    rest::binary
  >>) do
    s
    |> mode({:record, record_number, content_length})
    |> do_read(rest)
  end

  ##
  # Point
  #
  defp do_read(%State{mode: {:record, _, _}, shape_type: :point} = s, <<
    1::little-integer-size(32),
    x::little-float-size(64),
    y::little-float-size(64),
    rest::binary
  >>) do
    s
    |> emit(%Point{x: x, y: y})
    |> mode(:record_header)
    |> do_read(rest)
  end

  ##
  # Multipoints
  #
  defp do_read(%State{mode: {:record, _, _}, shape_type: :multipoint} = s, <<
    8::little-integer-size(32),
    xmin::little-float-size(64),
    ymin::little-float-size(64),
    xmax::little-float-size(64),
    ymax::little-float-size(64),
    num_points::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> repeatedly(num_points)
    |> item(%Multipoint{bbox: %Bbox{xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax}})
    |> mode(:multipoint)
    |> do_read(rest)
  end

  defp do_read(%State{mode: :multipoint, to_read: 0} = s, rest) do
    s
    |> mode(:record_header)
    |> reverse_item(:points)
    |> emit_item
    |> do_read(rest)
  end

  defp do_read(%State{mode: :multipoint, shape_type: :multipoint} = s, <<
    x::little-float-size(64),
    y::little-float-size(64),
    rest::binary
  >>) do
    s
    |> prepend(%Point{x: x, y: y}, :points)
    |> consume_item
    |> do_read(rest)
  end


  ##
  # Polylines
  #
  defp do_read(%State{mode: {:record, _, _}, shape_type: :polyline} = s, <<
    3::little-integer-size(32),
    xmin::little-float-size(64),
    ymin::little-float-size(64),
    xmax::little-float-size(64),
    ymax::little-float-size(64),
    num_parts::little-integer-size(32),
    num_points::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> repeatedly(num_parts)
    |> item(%Polyline{bbox: %Bbox{xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax}})
    |> mode({:parts, {:polyline, num_points}})
    |> do_read(rest)
  end

  defp do_read(%State{mode: :polyline, to_read: 0} = s, rest) do
    s
    |> mode(:record_header)
    |> reverse_item(:points)
    |> emit_item
    |> do_read(rest)
  end

  defp do_read(%State{mode: :polyline, shape_type: :polyline} = s, <<
    x::little-float-size(64),
    y::little-float-size(64),
    rest::binary
  >>) do
    s
    |> prepend(%Point{x: x, y: y}, :points)
    |> consume_item
    |> do_read(rest)
  end

  ##
  # Parts
  #
  defp do_read(%State{mode: {:parts, {next_mode, to_read}}, to_read: 0} = s, rest) do
    s
    |> reverse_item(:parts)
    |> mode(next_mode)
    |> repeatedly(to_read)
    |> do_read(rest)
  end
  defp do_read(%State{mode: {:parts, _}} = s, <<
    part::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> prepend(part, :parts)
    |> consume_item
    |> do_read(rest)
  end



  defp do_read(%State{} = s, <<rest::binary>>), do: {rest, s}

  def read(byte_stream) do
    Stream.transform(byte_stream, {<<>>, %State{}}, fn bin, {buf, state} ->
      case do_read(state, buf <> bin) do
        {_,   %State{mode: :done}} = s -> {:halt, s}
        {buf, %State{emit: emit} = s}-> {Enum.reverse(emit), {buf, %{s | emit: []}}}
      end
    end)
  end
end