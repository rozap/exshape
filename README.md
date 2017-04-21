# Exshape
Parse ESRI Shapefiles



## Usage
### Installation
Add 
```
{:exshape, "~> 0.1.0"}
```

to `mix.exs` deps

### From a zip archive
```elixir
[
  {"rivers", {prj, river_shapes}},
  {"lakes", {prj, lake_shapes}}
] = Exshape.from_zip("path/to/archive.zip")

Stream.each(river_shapes, &IO.inspect/1) |> Stream.run
Stream.each(lake_shapes, &IO.inspect/1) |> Stream.run
```

### Shapes from a SHP byte stream
```elixir
File.stream!("rivers.shp", [], 2048)
|> Exshape.Shp.read
|> Stream.each(&IO.inspect/1)
|> Stream.run
```

### Attributes from a DBF byte stream
```elixir
File.stream!("rivers.dbf", [], 2048)
|> Exshape.Dbf.read
|> Stream.each(&IO.inspect/1)
|> Stream.run
```
