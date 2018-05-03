defmodule ShpTest do
  use ExUnit.Case
  import TestHelper
  alias Exshape.Shp
  alias Exshape.Shp.{Bbox,
    Point, PointM,
    Multipoint, MultipointM,
    Polyline, PolylineM,
    Polygon, PolygonM
  }
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

  test "can read pointm" do
    [_header | pointms] = fixture("pointm.shp")
    |> Shp.read
    |> Enum.into([])

    assert pointms == [
      %PointM{x: 10, y: 10, m: 100},
      %PointM{x: 5, y: 5, m: 50},
      %PointM{x: 0, y: 10, m: 75}
    ]
  end

  test "can read multipointm" do
    [_header | multipointms] = fixture("multipointm.shp")
    |> Shp.read
    |> Enum.into([])

    assert multipointms == [
      %MultipointM{
        points: [
          %PointM{x: 10, y: 10, m: 100},
          %PointM{x: 5, y: 5, m: 50},
          %PointM{x: 0, y: 10, m: 75}
        ],
        bbox: %Bbox{xmin: 0, xmax: 10, ymin: 5, ymax: 10, mmax: 100, mmin: 50}
      }
    ]
  end

  test "can read polylinem" do
    [_header | polylinems] = fixture("polylinem.shp")
    |> Shp.read
    |> Enum.into([])

    assert polylinems == [
      %PolylineM{
        points: [
          [
            %PointM{x: 0, y: 0, m: 0},
            %PointM{x: 5, y: 5, m: 5},
            %PointM{x: 10, y: 10, m: 10},
          ]
        ],
        parts: [0],
        bbox: %Bbox{xmin: 0, xmax: 10, ymin: 0, ymax: 10, mmin: 0, mmax: 10}
      },
      %PolylineM{
        points: [
          [
            %PointM{x: 15, y: 15, m: 15},
            %PointM{x: 20, y: 20, m: 20},
            %PointM{x: 25, y: 25, m: 25}
          ]
        ],
        parts: [0],
        bbox: %Bbox{xmin: 15, xmax: 25, ymin: 15, ymax: 25, mmin: 15, mmax: 25}
      }
    ]
  end

  test "can read polygonm" do
    [_header | polygonms] = fixture("polygonm.shp")
    |> Shp.read
    |> Enum.into([])

    assert polygonms == [
      %PolygonM{
        points: [
          [
            %PointM{x: 0, y: 0, m: 0},
            %PointM{x: 0, y: 5, m: 5},
            %PointM{x: 5, y: 5, m: 10},
            %PointM{x: 5, y: 0, m: 15},
            %PointM{x: 0, y: 0, m: 0}
          ]
        ],
        parts: [0],
        bbox: %Bbox{xmin: 0, xmax: 5, ymin: 0, ymax: 5, mmin: 0, mmax: 15}
      }
    ]
  end

  test "can nest holes" do
    assert Shp.nest_polygon(%Polygon{
      parts: [0, 5],
      points: Enum.reverse([
        %Point{x: 0, y: 4},
        %Point{x: 4, y: 4},
        %Point{x: 4, y: 0},
        %Point{x: 0, y: 0},
        %Point{x: 0, y: 4},

        %Point{x: 2, y: 2},
        %Point{x: 1, y: 2},
        %Point{x: 1, y: 1},
        %Point{x: 2, y: 1},
        %Point{x: 2, y: 2}
      ])
    }) == [
      [
        %Point{x: 0, y: 4},
        %Point{x: 4, y: 4},
        %Point{x: 4, y: 0},
        %Point{x: 0, y: 0},
        %Point{x: 0, y: 4},
      ],
      [
        %Point{x: 2, y: 2},
        %Point{x: 1, y: 2},
        %Point{x: 1, y: 1},
        %Point{x: 2, y: 1},
        %Point{x: 2, y: 2}
      ]
    ]
  end

  test "clockwise" do
    assert Shp.is_clockwise?(
      [
        %Point{x: 0, y: 4},
        %Point{x: 4, y: 4},
        %Point{x: 4, y: 0},
        %Point{x: 0, y: 0},
        %Point{x: 0, y: 4}
      ]) == true

    assert Shp.is_clockwise?(
      [
        %Point{x: 4, y: 4},
        %Point{x: 0, y: 4},
        %Point{x: 0, y: 0},
        %Point{x: 4, y: 0},
        %Point{x: 4, y: 4}
      ]) == false
  end

  test "can nest many holes" do
    assert Shp.nest_polygon(%Polygon{
      parts: [0, 5, 10],
      points: Enum.reverse([
        %Point{x: 0, y: 5},
        %Point{x: 5, y: 5},
        %Point{x: 5, y: 0},
        %Point{x: 0, y: 0},
        %Point{x: 0, y: 5},

        %Point{x: 2, y: 2},
        %Point{x: 1, y: 2},
        %Point{x: 1, y: 1},
        %Point{x: 2, y: 1},
        %Point{x: 2, y: 2},

        %Point{x: 4, y: 3},
        %Point{x: 3, y: 3},
        %Point{x: 3, y: 2},
        %Point{x: 4, y: 2},
        %Point{x: 4, y: 3}
      ])
    }) == [
      [
        %Point{x: 0, y: 5},
        %Point{x: 5, y: 5},
        %Point{x: 5, y: 0},
        %Point{x: 0, y: 0},
        %Point{x: 0, y: 5},
      ],
      [
        %Point{x: 2, y: 2},
        %Point{x: 1, y: 2},
        %Point{x: 1, y: 1},
        %Point{x: 2, y: 1},
        %Point{x: 2, y: 2}
      ],
      [
        %Point{x: 4, y: 3},
        %Point{x: 3, y: 3},
        %Point{x: 3, y: 2},
        %Point{x: 4, y: 2},
        %Point{x: 4, y: 3}
      ]
    ]
  end
end
