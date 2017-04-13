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
        %Column{field_length: 8, field_type: :date, name: "A_DATE"},
        %Column{field_length: 8, field_type: :float, name: "A_FLOAT"},
        %Column{field_length: 18, field_type: :numeric, name: "A_NUMBER"},
        %Column{field_length: 1, field_type: :boolean, name: "A_BOOL"},
        %Column{field_length: 15, field_type: :character, name: "A_CHAR"}],
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
      ["some chars", true, 4, 8.8, {:ok, ~D[1980-10-11]}],
      ["more chars", false, 1, 2.2, {:ok, ~D[1980-12-11]}],
      ["more characters", false, 1, 2.2, {:ok, ~D[1980-12-11]}]
    ]
  end


end
