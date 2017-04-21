# Exshape
Parse ESRI Shapefiles

## From a zip archive
```elixir
[
  {"rivers", {prj, river_shapes}},
  {"lakes", {prj, lake_shapes}}
] = Exshape.from_zip("path/to/archive.zip")

Stream.each(river_shapes, &IO.inspect/1) |> Stream.run
Stream.each(lake_shapes, &IO.inspect/1) |> Stream.run
```