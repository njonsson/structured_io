defmodule StructuredIOTest do
  use ExUnit.Case
  doctest StructuredIO

  setup do
    {:ok, structured_io} = StructuredIO.start_link
    {:ok, structured_io: structured_io}
  end

  describe ".binread_across/3" do
    test "before .binwrite/2", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      assert StructuredIO.binread_across(structured_io, opener, closer) == ""
    end

    @tag :slow
    test "with a large dataset", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      scan_data = opener                                          <>
                  String.duplicate(<<0, 0, 0, 1, 2, 3>>, 524_288) <>
                  closer
      :ok = StructuredIO.binwrite(structured_io, scan_data)
      assert StructuredIO.binread_across(structured_io,
                                         opener,
                                         closer) == scan_data
    end

    test "after .write/2", %{structured_io: structured_io} do
      opener = "<elem>"
      closer = "</elem>"
      scan_data = opener <> "foo" <> closer
      :ok = StructuredIO.write(structured_io, scan_data)
      assert StructuredIO.binread_across(structured_io, opener, closer) ==
             {:error,
              "In Unicode mode -- call StructuredIO.read_across/3 instead"}
    end
  end

  describe ".read_across/3" do
    test "before .write/2", %{structured_io: structured_io} do
      opener = "<elem>"
      closer = "</elem>"
      assert StructuredIO.read_across(structured_io, opener, closer) == ""
    end

    test "after .binwrite/2", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      scan_data = opener <> <<0, 0, 0, 1, 2, 3>> <> closer
      :ok = StructuredIO.binwrite(structured_io, scan_data)
      assert StructuredIO.read_across(structured_io, opener, closer) ==
             {:error,
              "In binary mode -- call StructuredIO.binread_across/3 instead"}
    end
  end
end
