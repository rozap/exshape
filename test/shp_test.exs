defmodule ShpTest do
  use ExUnit.Case
  import TestHelper
  alias Exshape.Shp
  alias Exshape.Shp.{Bbox, Point, Multipoint, Polyline, Polygon}
  doctest Exshape

  test "can read points" do
    [_header | points] = fixture("point.shp")
    |> Shp.read
    |> Enum.into([])

    assert [
      %Point{x: 10, y: 10},
      %Point{x: 5, y: 5},
      %Point{x: 0, y: 10}
    ] == points
  end

  test "can read multipoints" do
    [_header, multipoint] = fixture("multipoint.shp")
    |> Shp.read
    |> Enum.into([])

    assert multipoint == %Multipoint{
      points: [
        %Point{x: 10, y: 10},
        %Point{x: 5, y: 5},
        %Point{x: 0, y: 10}
      ],
      bbox: %Bbox{xmin: 0, ymin: 5, xmax: 10, ymax: 10}
    }
  end

  test "can read polyline" do
    [_ | lines] = fixture("polyline.shp")
    |> Shp.read
    |> Enum.into([])

    assert lines == [
      %Polyline{
        parts: [0],
        points: [
          [
            %Point{x: 0, y: 0},
            %Point{x: 5, y: 5},
            %Point{x: 10, y: 10}
          ]
        ],
        bbox: %Bbox{xmin: 0, ymin: 0, xmax: 10, ymax: 10}
      },
      %Polyline{
        parts: [0],
        points: [
          [
            %Point{x: 15, y: 15},
            %Point{x: 20, y: 20},
            %Point{x: 25, y: 25}
          ]
        ],
        bbox: %Bbox{xmin: 15, ymin: 15, xmax: 25, ymax: 25}
      }
    ]
  end

  test "can read polygons" do
    [_header, polygon] = fixture("polygons.shp")
    |> Shp.read
    |> Enum.into([])

    assert polygon == %Polygon{
      points: [
        [
          %Point{x: 0, y: 0},
          %Point{x: 0, y: 5},
          %Point{x: 5, y: 5},
          %Point{x: 5, y: 0},
          %Point{x: 0, y: 0}
        ],
        [
          %Point{x: 0, y: 0},
          %Point{x: 0, y: 5},
          %Point{x: 5, y: 5},
          %Point{x: 5, y: 0},
          %Point{x: 0, y: 0}
        ]
      ],
      parts: [0, 5],
      bbox: %Bbox{xmin: 0, ymin: 0, xmax: 5, ymax: 5}
    }
  end
end
