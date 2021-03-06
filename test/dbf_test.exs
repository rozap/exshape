defmodule DbfTest do
  use ExUnit.Case
  import TestHelper
  alias Exshape.Dbf
  alias Exshape.Dbf.{Column, Header}

  test "can read the header" do
    [header | _] = fixture("all_fields.dbf")
    |> Dbf.read
    |> Enum.into([])

    assert header == %Header{
      columns: [
        %Column{field_length: 15, field_type: :character, name: "A_CHAR"},
        %Column{field_length: 1, field_type: :boolean, name: "A_BOOL"},
        %Column{field_length: 18, field_type: :numeric, name: "A_NUMBER"},
        %Column{field_length: 8, field_type: :float, name: "A_FLOAT"},
        %Column{field_length: 8, field_type: :date, name: "A_DATE"}
      ],
      header_byte_count: 193, last_updated: {2015, 9, 7},
      record_byte_count: 51,
      record_count: 3
    }
  end

  test "can read the records" do
    [_header | records] = fixture("all_fields.dbf")
    |> Dbf.read
    |> Enum.into([])

    records = Enum.map(records, fn row -> Enum.map(row, fn
      bin when is_binary(bin) -> String.trim(bin)
      other -> other
    end) end)

    assert records == [
      ["some chars", true, 4, 8.8, ~D[1980-10-11]],
      ["more chars", false, 1, 2.2, ~D[1980-12-11]],
      ["more characters", false, 1, 2.2, ~D[1980-12-11]]
    ]
  end

  test "uninitialized logical fields" do
    assert fixture("uninitialized_logical.dbf")
    |> Dbf.read
    |> Enum.into([])
    |> length == 35
  end


  test "with padding on numeric fields" do
    [_header, [numeric_cell]] = fixture("with_number_padding.dbf")
    |> Dbf.read
    |> Enum.into([])

    assert numeric_cell == 13
  end
end
