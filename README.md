# Exshape
Parse ESRI Shapefiles
[![Build Status](https://travis-ci.org/rozap/exshape.svg?branch=master)](https://travis-ci.org/rozap/exshape)



## Usage
### Installation
Add

```elixir
{:exshape, "~> 2.2"}
```

to `mix.exs` deps

### From a zip archive
```elixir
[
  {"rivers", rivers_proj, river_shapes},
  {"lakes", lakes_proj, lake_shapes}
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
