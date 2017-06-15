defmodule ExshapeTest do
  use ExUnit.Case
  doctest Exshape
  import TestHelper

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

  # These are just smoke tests

  @moduletag timeout: 60_000 * 5
  test "can read a thing" do
    # :fprof.trace([:start, {:procs, self}])
    [{_layer_name, _prj, stream}] = Exshape.from_zip(
      "#{__DIR__}/fixtures/co-parcels.zip"
    )

    assert Enum.reduce(stream, 0, fn _, acc -> acc + 1 end) == 7743
  end

  test "zillow validity" do
    [{_layer_name, _prj, stream}] = Exshape.from_zip(
      "#{__DIR__}/fixtures/zillow.zip"
    )

    stream
    |> Stream.drop(1)
    |> Stream.each(fn {%Exshape.Shp.Polygon{points: points}, _attrs} ->
      Enum.each(points, fn part ->
        assert List.first(part) == List.last(part)
      end)
    end)
    |> Stream.run
  end

  test "howard beach" do
    [{_layer_name, _prj, stream}] = Exshape.from_zip(
      "#{__DIR__}/fixtures/howard-beach.zip"
    )

    [{%Exshape.Shp.Polygon{points: [_, ring]}, _attrs}] = stream
    |> Stream.drop(1)
    |> Enum.into([])

    assert ring == [
      %Exshape.Shp.Point{x: -73.85161361099966, y: 40.64986601600033},
      %Exshape.Shp.Point{x: -73.85169718399973, y: 40.64982533900025},
      %Exshape.Shp.Point{x: -73.85164616599978, y: 40.649837659000205},
      %Exshape.Shp.Point{x: -73.85162201099982, y: 40.649846004000274},
      %Exshape.Shp.Point{x: -73.85161361099966, y: 40.64986601600033}
    ]
  end

  test "hoods" do
    assert fixture("Neighborhoods/neighborhoods_orleans.shp")
    |> Exshape.Shp.read
    |> Enum.into([])
    |> length == 75
  end
end
