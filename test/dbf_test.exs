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

    assert records == [
      %{"A_CHAR" => "some chars", "A_BOOL" => true, "A_NUMBER" => 4, "A_FLOAT" => 8.8, "A_DATE" => ~D[1980-10-11]},
      %{"A_CHAR" => "more chars", "A_BOOL" => false, "A_NUMBER" => 1, "A_FLOAT" => 2.2, "A_DATE" => ~D[1980-12-11]},
      %{"A_CHAR" => "more characters", "A_BOOL" => false, "A_NUMBER" => 1, "A_FLOAT" => 2.2, "A_DATE" => ~D[1980-12-11]},
    ]
  end

  test "uninitialized logical fields" do
    assert fixture("uninitialized_logical.dbf")
    |> Dbf.read
    |> Enum.into([])
    |> length == 35
  end
end
