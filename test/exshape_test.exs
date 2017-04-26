defmodule ExshapeTest do
  use ExUnit.Case
  doctest Exshape

  test "can read from zip" do
    [{"point", _prj, stream}] = Exshape.from_zip(
      "#{__DIR__}/fixtures/archive.zip"
    )

    [
      {shp_header, dbf_header},
      {p0, [nil]},
      {p1, [nil]},
      {p2, [nil]}
    ] = Enum.into(stream, [])

    assert shp_header.bbox == %Exshape.Shp.Bbox{
      mmax: 0.0,
      mmin: 0.0,
      xmax: 10.0,
      xmin: 0.0,
      ymax: 10.0,
      ymin: 5.0,
      zmax: 0.0,
      zmin: 0.0
    }

    assert dbf_header.columns ==  [
      %Exshape.Dbf.Column{
        field_length: 5,
        field_type: :numeric,
        name: "point_ID"
      }
    ]

    assert [p0, p1, p2] == [
      %Exshape.Shp.Point{x: 10.0, y: 10.0},
      %Exshape.Shp.Point{x: 5.0, y: 5.0},
      %Exshape.Shp.Point{x: 0.0, y: 10.0}
    ]
  end

  # defp system_time do
  #   {mega, seconds, ms} = :os.timestamp()
  #   (mega*1000000 + seconds)*1000 + :erlang.round(ms/1000)
  # end

  @moduletag timeout: 60_000 * 5
  test "can read a thing" do
    # :fprof.trace([:start, {:procs, self}])
    [{_layer_name, _prj, stream}] = Exshape.from_zip(
      "#{__DIR__}/fixtures/co-parcels.zip"
    )

    # start = system_time()
    assert Enum.reduce(stream, 0, fn _, acc -> acc + 1 end) == 7743
    # IO.inspect {:elapsed, (system_time() - start), :ms}
  end
end
