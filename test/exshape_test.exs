defmodule ExshapeTest do
  use ExUnit.Case
  doctest Exshape

  test "can read from zip" do
    [{"point", {_prj, stream}}] = Exshape.from_zip(
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
end
