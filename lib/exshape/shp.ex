defmodule Exshape.Shp do
  defmodule State do
    defstruct mode: :header,
      shape_type: nil,
      emit: [],
      to_read: nil,
      item: nil,
      part_index: 0,
      measures: []
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

  defmodule PointM do
    defstruct [:x, :y, :m]
  end

  defmodule Multipoint do
    defstruct points: [], bbox: nil
  end

  defmodule MultipointM do
    defstruct points: [], bbox: nil
  end

  defmodule Polyline do
    defstruct points: [], bbox: nil, parts: []
  end

  defmodule PolylineM do
    defstruct points: [], bbox: nil, parts: []
  end

  defmodule PolygonM do
    defstruct points: [], bbox: nil, parts: []
  end


  defmodule Polygon do
    defstruct points: [], bbox: nil, parts: []
  end


  @file_code <<9994::big-integer-size(32)>>
  @unused <<0::big-integer-size(32)>>
  @version <<1000::little-integer-size(32)>>

  Enum.each([{0, nil, nil},
  {1, :point, Point},
  {3, :polyline, Polyline},
  {5, :polygon, Polygon},
  {8, :multipoint, Multipoint},
  {11, :pointz, nil}, #Not implemented
  {13, :polylinez, nil},
  {15, :polygonz, nil},
  {18, :multipointz, nil},
  {21, :pointm, PointM},
  {23, :polylinem, PolylineM},
  {25, :polygonm, PolygonM},
  {28, :multipointm, MultipointM},
  {31, :multipatchm, nil}], fn {code, t, s} ->
    def shape_type_from_code(unquote(code)), do: unquote(t)
    def shape_type_to_struct(unquote(t)), do: struct!(unquote(s))
  end)

  defp nest_parts(item) do
    {parts, _} = item.points
    |> Enum.reverse
    |> Enum.reduce({[], 0}, fn
      point, {[], 0} -> {[[point]], 1}
      point, {nested, i} ->
        if i in item.parts do
          {[[point] | nested], i + 1}
        else
          [nest | rest_nested] = nested
          {[[point | nest] | rest_nested], i + 1}
        end
    end)

    parts
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse
  end

  defp zip_measures(p, s) do
    points = p.points
    |> Enum.zip(s.measures)
    |> Enum.map(fn {pm, m} -> %{pm | m: m} end)

    %{p | points: points}
  end

  defp emit(s, %Polygon{} = p) do
    %{s | emit: [%{p | points: nest_polygon(p)} | s.emit]}
  end

  defp emit(s, %Polyline{} = p) do
    %{s | emit: [%{p | points: nest_parts(p)} | s.emit]}
  end

  defp emit(s, %Multipoint{} = mp) do
    %{s | emit: [reverse(mp, :points) | s.emit]}
  end

  defp emit(s, %MultipointM{} = mp) do
    mp = zip_measures(mp, s) |> reverse(:points)
    %{s | emit: [mp | s.emit]}
  end

  defp emit(s, %PolylineM{} = pm) do
    p = zip_measures(pm, s)
    polylinem = %{p | points: nest_parts(p)}
    %{s | emit: [polylinem | s.emit]}
  end

  defp emit(s, %PolygonM{} = pm) do
    p = zip_measures(pm, s)
    polylinem = %{p | points: nest_polygon(p)}
    %{s | emit: [polylinem | s.emit]}
  end

  defp emit(s, thing), do: %{s | emit: [thing | s.emit], item: nil}


  defp mode(s, m), do: %{s | mode: m}
  defp shape_type(s, st), do: %{s | shape_type: st}
  defp item(s, item), do: %{s | item: item}
  defp repeatedly(s, n), do: %{s | to_read: n}
  defp prepend(s, p, key) do
    %{s | item: Map.put(s.item, key, [p | Map.get(s.item, key)])}
  end
  defp consume_item(s), do: %{s | to_read: s.to_read - 1}
  defp emit_item(s), do: %{emit(s, s.item) | item: nil}
  defp reverse(item, key) do
    Map.put(item, key, Enum.reverse(Map.get(item, key)))
  end

  defp put_measure(s, m), do: %{s | measures: [m | s.measures]}

  def nest_polygon(p) do
    {polys, holes} = nest_parts(p)
    |> Enum.reduce({[], []}, fn ring, {polys, holes} ->
      if is_clockwise?(ring) do
        {[[ring] | polys], holes}
      else
        {polys, [ring | holes]}
      end
    end)


    Enum.reverse(holes)
    |> Enum.reduce(Enum.reverse(polys), fn hole, polys ->
      nest_hole(hole, polys)
    end)
  end

  def nest_hole(hole, []), do: [[hole]]
  def nest_hole([point | _] = hole, [[first_ring | _] = poly | rest_polys]) do
    if ring_contains?(first_ring, point) do
      [poly ++ [hole] | rest_polys]
    else
      nest_hole(hole, rest_polys)
    end
  end

  def is_clockwise?(points) when length(points) < 4, do: false
  def is_clockwise?([prev | points]) do
    {_, area} = Enum.reduce(points, {prev, 0}, fn %{x: x, y: y} = np, {%{x: xp, y: yp}, s} ->
      {np, s + (x - xp) * (y + yp)}
    end)

    area >= 0
  end

  def ring_contains?([], _), do: false
  def ring_contains?(ring, %{x: x, y: y}) do
    {_, c} = Enum.reduce(ring, {List.last(ring), false}, fn %{x: ix, y: iy} = i, {%{x: jx, y: jy}, c} ->
      c = if ((iy > y) != (jy > y)) && (x < ((((jx - ix) * (y - iy)) / (jy - iy)) + ix)) do
        c = !c
      else
        c
      end

      {i, c}
    end)

    c
  end

  defp extract_bbox(<<
    xmin::little-float-size(64),
    ymin::little-float-size(64),
    xmax::little-float-size(64),
    ymax::little-float-size(64)
  >>) do
    %Bbox{xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax}
  end
  defp extract_bbox(_), do: %Bbox{}

  defp update_bbox_measures(bbox, <<
    mmin::little-float-size(64),
    mmax::little-float-size(64),
  >>) do
    %{bbox | mmin: mmin, mmax: mmax}
  end
  defp update_bbox_measures(bbox, _), do: bbox

  defp do_read(%State{mode: :header} = s, <<
    @file_code,
    @unused,
    @unused,
    @unused,
    @unused,
    @unused,
    _file_len::big-integer-size(32),
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

  defp do_read(%State{mode: {:record, _, _}, shape_type: _} = s, <<
    0::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> emit(nil)
    |> mode(:record_header)
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
    bbox::binary-size(32),
    num_points::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> repeatedly(num_points)
    |> item(%Multipoint{bbox: extract_bbox(bbox)})
    |> mode(:multipoint)
    |> do_read(rest)
  end

  defp do_read(%State{mode: :multipoint, to_read: 0} = s, rest) do
    s
    |> mode(:record_header)
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
    bbox::binary-size(32),
    num_parts::little-integer-size(32),
    num_points::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> repeatedly(num_parts)
    |> item(%Polyline{bbox: extract_bbox(bbox)})
    |> mode({:parts, {:polyline, num_points}})
    |> do_read(rest)
  end

  defp do_read(%State{mode: :polyline, to_read: 0} = s, rest) do
    s
    |> mode(:record_header)
    |> emit(s.item)
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
  # Polygons
  #
  defp do_read(%State{mode: {:record, _, _}, shape_type: :polygon} = s, <<
    5::little-integer-size(32),
    bbox::binary-size(32),
    num_parts::little-integer-size(32),
    num_points::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> repeatedly(num_parts)
    |> item(%Polygon{bbox: extract_bbox(bbox)})
    |> mode({:parts, {:polygon, num_points}})
    |> do_read(rest)
  end

  defp do_read(%State{mode: :polygon, to_read: 0} = s, rest) do
    s
    |> mode(:record_header)
    |> emit(s.item)
    |> do_read(rest)
  end

  defp do_read(%State{mode: :polygon, shape_type: :polygon} = s, <<
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
  # PointM
  #
  defp do_read(%State{mode: {:record, _, _}, shape_type: :pointm} = s, <<
    21::little-integer-size(32),
    x::little-float-size(64),
    y::little-float-size(64),
    m::little-float-size(64),
    rest::binary
  >>) do
    s
    |> emit(%PointM{x: x, y: y, m: m})
    |> mode(:record_header)
    |> do_read(rest)
  end

  ##
  # MultipointM
  #
  defp do_read(%State{mode: {:record, _, _}, shape_type: :multipointm} = s, <<
    28::little-integer-size(32),
    bbox::binary-size(32),
    num_points::little-integer-size(32),
    rest::binary
  >>) do
    s
    |> repeatedly(num_points)
    |> item(%MultipointM{bbox: extract_bbox(bbox)})
    |> mode(:multipointm)
    |> do_read(rest)
  end



  defp do_read(%State{mode: :multipointm, to_read: 0} = s, <<
    bbox_measures::binary-size(16),
    rest::binary
  >>) do
    num_points = length(s.item.points)
    bbox = update_bbox_measures(s.item.bbox, bbox_measures)

    s
    |> mode(:measures)
    |> repeatedly(num_points)
    |> item(%{s.item | bbox: bbox})
    |> do_read(rest)
  end

  defp do_read(%State{mode: :multipointm, shape_type: :multipointm} = s, <<
    x::little-float-size(64),
    y::little-float-size(64),
    rest::binary
  >>) do
    s
    |> prepend(%PointM{x: x, y: y}, :points)
    |> consume_item
    |> do_read(rest)
  end

  ##
  # PolylineM and PolygonM are the same
  @poly_m [:polylinem, :polygonm]
  @poly_m_t %{
    polylinem: PolylineM,
    polygonm: PolygonM
  }

  defp do_read(%State{mode: {:record, _, _}, shape_type: st} = s, <<
    _::little-integer-size(32),
    bbox::binary-size(32),
    num_parts::little-integer-size(32),
    num_points::little-integer-size(32),
    rest::binary
  >>) when st in @poly_m do

    t = Map.get(@poly_m_t, st)
    item = struct(t, %{bbox: extract_bbox(bbox)})

    s
    |> repeatedly(num_parts)
    |> item(item)
    |> mode({:parts, {st, num_points}})
    |> do_read(rest)
  end

  defp do_read(%State{mode: mode, to_read: 0} = s, <<
    bbox_measures::binary-size(16),
    rest::binary
  >>) when mode in @poly_m do
    num_points = length(s.item.points)
    item = %{s.item | bbox: update_bbox_measures(s.item.bbox, bbox_measures)}

    s
    |> mode(:measures)
    |> item(item)
    |> repeatedly(num_points)
    |> do_read(rest)
  end

  defp do_read(%State{mode: st, shape_type: st} = s, <<
    x::little-float-size(64),
    y::little-float-size(64),
    rest::binary
  >>) when st in @poly_m  do
    s
    |> prepend(%PointM{x: x, y: y}, :points)
    |> consume_item
    |> do_read(rest)
  end

  ##
  # Parts
  #
  defp do_read(%State{mode: {:parts, {next_mode, to_read}}, to_read: 0} = s, rest) do
    s
    |> item(reverse(s.item, :parts))
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

  ##
  # Measures
  #
  defp do_read(%State{mode: :measures, to_read: 0} = s, rest) do

    s
    |> mode(:record_header)
    |> emit(s.item)
    |> do_read(rest)
  end

  defp do_read(%State{mode: :measures} = s, <<
    m::little-float-size(64),
    rest::binary
  >>) do
    s
    |> put_measure(m)
    |> consume_item
    |> do_read(rest)
  end
  defp do_read(%State{} = s, <<rest::binary>>) do
    {rest, s}
  end

  @doc """
    Read geometry features from a byte stream

    ```
      File.stream!("rivers.shp", [], 2048)
      |> Exshape.Shp.read
      |> Stream.run
    ```
  """
  def read(byte_stream) do
    Stream.transform(byte_stream, {<<>>, %State{}}, fn bin, {buf, state} ->
      case do_read(state, buf <> bin) do
        {_,   %State{mode: :done}} = s -> {:halt, s}
        {buf, %State{emit: emit} = s}-> {Enum.reverse(emit), {buf, %{s | emit: []}}}
      end
    end)
  end

end
