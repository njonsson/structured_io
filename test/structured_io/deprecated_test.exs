defmodule StructuredIO.DeprecatedTest do
  use ExUnit.Case, async: true
  doctest StructuredIO.Deprecated

  setup do
    Logger.disable self()
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

    @tag :slow
    test "with a large dataset", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      :ok = StructuredIO.binwrite(structured_io, opener)
      with_random_io_lists %{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.binwrite(structured_io, io_list)
      end
      :ok = StructuredIO.binwrite(structured_io, closer)
      result = StructuredIO.binread_across(structured_io,
                                           opener,
                                           closer,
                                           12_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == byte_size(opener) +
                                 20_000_000        +
                                 byte_size(closer)
      beginning_of_result = binary_part(result, 0, byte_size(opener))
      assert beginning_of_result == opener
      end_of_result = binary_part(result,
                                  result_byte_size - byte_size(closer),
                                  byte_size(closer))
      assert end_of_result == closer
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

    @tag :slow
    test "with a large dataset", %{structured_io: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      :ok = StructuredIO.binwrite(structured_io, opener)
      with_random_io_lists %{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.binwrite(structured_io, io_list)
      end
      :ok = StructuredIO.binwrite(structured_io, closer)
      result = StructuredIO.binread_between(structured_io,
                                            opener,
                                            closer,
                                            12_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000
      beginning_of_result = binary_part(result, 0, byte_size(opener))
      refute beginning_of_result == opener
      end_of_result = binary_part(result,
                                  result_byte_size - byte_size(closer),
                                  byte_size(closer))
      refute end_of_result == closer
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

    @tag :slow
    test "with a large dataset", %{structured_io: structured_io} do
      delimiter = <<255, 255, 255, 255, 255>>
      with_random_io_lists %{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.binwrite(structured_io, io_list)
      end
      :ok = StructuredIO.binwrite(structured_io, delimiter)
      result = StructuredIO.binread_through(structured_io, delimiter, 12_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000 + byte_size(delimiter)
      end_of_result = binary_part(result,
                                  result_byte_size - byte_size(delimiter),
                                  byte_size(delimiter))
      assert end_of_result == delimiter
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

    @tag :slow
    test "with a large dataset", %{structured_io: structured_io} do
      opener = <<0, 0, 0, 0, 0>>
      with_random_io_lists %{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.binwrite(structured_io, io_list)
      end
      :ok = StructuredIO.binwrite(structured_io, opener)
      result = StructuredIO.binread_to(structured_io, opener, 12_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000
      end_of_result = binary_part(result,
                                  result_byte_size - byte_size(opener),
                                  byte_size(opener))
      assert end_of_result != opener
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
