defmodule StructuredIO.DeprecatedTest do
  use ExUnit.Case, async: true
  doctest StructuredIO.Deprecated

  setup do
    {:ok, structured_io} = StructuredIO.start_link
    {:ok, structured_io: structured_io}
  end

  def with_random_io_lists(%{size: size, count: count}, fun) do
    for _ <- 1..count do
      0..255
      |> Enum.take_random(size)
      |> fun.()
    end
  end

  describe ".binread_across/3" do
    test "before .binwrite/2", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      assert StructuredIO.binread_across(structured_io, opener, closer) == ""
    end

    test "in Unicode mode", %{structured_io: structured_io} do
      opener = "<elem>"
      closer = "</elem>"
      scan_data = opener <> "foo" <> closer
      :ok = StructuredIO.write(structured_io, scan_data)
      assert StructuredIO.binread_across(structured_io, opener, closer) ==
             {:error,
              "In Unicode mode -- call StructuredIO.read_across/3 instead"}
    end
  end

  describe ".binread_between/3" do
    test "before .binwrite/2", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      assert StructuredIO.binread_between(structured_io, opener, closer) == ""
    end

    test "in Unicode mode", %{structured_io: structured_io} do
      opener = "<elem>"
      closer = "</elem>"
      scan_data = opener <> "foo" <> closer
      :ok = StructuredIO.write(structured_io, scan_data)
      assert StructuredIO.binread_between(structured_io, opener, closer) ==
             {:error,
              "In Unicode mode -- call StructuredIO.read_between/3 instead"}
    end
  end

  describe ".binread_through/2" do
    test "before .binwrite/2", %{structured_io: structured_io} do
      delimiter = <<255, 255, 255>>
      assert StructuredIO.binread_through(structured_io, delimiter) == ""
    end

    test "in Unicode mode", %{structured_io: structured_io} do
      delimiter = "<br/>"
      scan_data = "foo" <> delimiter
      :ok = StructuredIO.write(structured_io, scan_data)
      assert StructuredIO.binread_through(structured_io, delimiter) ==
             {:error,
              "In Unicode mode -- call StructuredIO.read_through/2 instead"}
    end
  end

  describe ".binread_to/2" do
    test "before .binwrite/2", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      assert StructuredIO.binread_to(structured_io, opener) == ""
    end

    test "in Unicode mode", %{structured_io: structured_io} do
      opener = "<elem>"
      scan_data = "foo" <> opener
      :ok = StructuredIO.write(structured_io, scan_data)
      assert StructuredIO.binread_to(structured_io, opener) ==
             {:error, "In Unicode mode -- call StructuredIO.read_to/2 instead"}
    end
  end

  describe ".read_across/3" do
    test "before .write/2", %{structured_io: structured_io} do
      opener = "<elem>"
      closer = "</elem>"
      assert StructuredIO.read_across(structured_io, opener, closer) == ""
    end
  end

  describe ".read_between/3" do
    test "before .write/2", %{structured_io: structured_io} do
      opener = "<elem>"
      closer = "</elem>"
      assert StructuredIO.read_between(structured_io, opener, closer) == ""
    end
  end

  describe ".read_through/2" do
    test "before .write/2", %{structured_io: structured_io} do
      delimiter = "<br/>"
      assert StructuredIO.read_through(structured_io, delimiter) == ""
    end
  end

  describe ".read_to/2" do
    test "before .write/2", %{structured_io: structured_io} do
      opener = "<elem>"
      assert StructuredIO.read_to(structured_io, opener) == ""
    end
  end
end
