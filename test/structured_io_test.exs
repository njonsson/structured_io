defmodule StructuredIOTest do
  use ExUnit.Case, async: true
  doctest StructuredIO

  setup do
    {:ok, structured_io_binary_mode} = StructuredIO.start_link(:binary)
    {:ok, structured_io_unicode_mode} = StructuredIO.start_link(:unicode)

    {:ok,
     structured_io_binary_mode: structured_io_binary_mode,
     structured_io_unicode_mode: structured_io_unicode_mode}
  end

  def with_random_io_lists(%{size: size, count: count}, fun) do
    for _ <- 1..count do
      0..255
      |> Enum.take_random(size)
      |> fun.()
    end
  end

  describe ".read_across/3" do
    test "before .write/2", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      assert StructuredIO.read_across(structured_io, opener, closer) == ""
    end

    @tag :slow
    test "with a large dataset", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      :ok = StructuredIO.write(structured_io, opener)

      with_random_io_lists(%{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.write(structured_io, io_list)
      end)

      :ok = StructuredIO.write(structured_io, closer)
      result = StructuredIO.read_across(structured_io, opener, closer, 18_000)
      result_byte_size = byte_size(result)

      assert result_byte_size ==
               byte_size(opener) +
                 20_000_000 +
                 byte_size(closer)

      beginning_of_result = binary_part(result, 0, byte_size(opener))
      assert beginning_of_result == opener

      end_of_result =
        binary_part(
          result,
          result_byte_size - byte_size(closer),
          byte_size(closer)
        )

      assert end_of_result == closer
    end
  end

  describe ".read_across_ignoring_overlap/3" do
    @tag :slow
    test "with a large dataset", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      :ok = StructuredIO.write(structured_io, opener)

      with_random_io_lists(%{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.write(structured_io, io_list)
      end)

      :ok = StructuredIO.write(structured_io, closer)

      result =
        StructuredIO.read_across_ignoring_overlap(
          structured_io,
          opener,
          closer,
          15_000
        )

      result_byte_size = byte_size(result)

      assert result_byte_size ==
               byte_size(opener) +
                 20_000_000 +
                 byte_size(closer)

      beginning_of_result = binary_part(result, 0, byte_size(opener))
      assert beginning_of_result == opener

      end_of_result =
        binary_part(
          result,
          result_byte_size - byte_size(closer),
          byte_size(closer)
        )

      assert end_of_result == closer
    end
  end

  describe ".read_between/3" do
    test "before .write/2", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      assert StructuredIO.read_between(structured_io, opener, closer) == ""
    end

    @tag :slow
    test "with a large dataset", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      :ok = StructuredIO.write(structured_io, opener)

      with_random_io_lists(%{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.write(structured_io, io_list)
      end)

      :ok = StructuredIO.write(structured_io, closer)
      result = StructuredIO.read_between(structured_io, opener, closer, 18_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000
      beginning_of_result = binary_part(result, 0, byte_size(opener))
      refute beginning_of_result == opener

      end_of_result =
        binary_part(
          result,
          result_byte_size - byte_size(closer),
          byte_size(closer)
        )

      refute end_of_result == closer
    end
  end

  describe ".read_between_ignoring_overlap/3" do
    @tag :slow
    test "with a large dataset", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      :ok = StructuredIO.write(structured_io, opener)

      with_random_io_lists(%{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.write(structured_io, io_list)
      end)

      :ok = StructuredIO.write(structured_io, closer)

      result =
        StructuredIO.read_between_ignoring_overlap(
          structured_io,
          opener,
          closer,
          15_000
        )

      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000
      beginning_of_result = binary_part(result, 0, byte_size(opener))
      refute beginning_of_result == opener

      end_of_result =
        binary_part(
          result,
          result_byte_size - byte_size(closer),
          byte_size(closer)
        )

      refute end_of_result == closer
    end
  end

  describe ".read_through/2" do
    test "before .write/2", %{structured_io_binary_mode: structured_io} do
      delimiter = <<255, 255, 255>>
      assert StructuredIO.read_through(structured_io, delimiter) == ""
    end

    @tag :slow
    test "with a large dataset", %{structured_io_binary_mode: structured_io} do
      delimiter = <<255, 255, 255, 255, 255>>

      with_random_io_lists(%{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.write(structured_io, io_list)
      end)

      :ok = StructuredIO.write(structured_io, delimiter)
      result = StructuredIO.read_through(structured_io, delimiter, 15_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000 + byte_size(delimiter)

      end_of_result =
        binary_part(
          result,
          result_byte_size - byte_size(delimiter),
          byte_size(delimiter)
        )

      assert end_of_result == delimiter
    end
  end

  describe ".read_to/2" do
    test "before .write/2", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0>>
      assert StructuredIO.read_to(structured_io, opener) == ""
    end

    @tag :slow
    test "with a large dataset", %{structured_io_binary_mode: structured_io} do
      opener = <<0, 0, 0, 0, 0>>

      with_random_io_lists(%{size: 100, count: 200_000}, fn io_list ->
        :ok = StructuredIO.write(structured_io, io_list)
      end)

      :ok = StructuredIO.write(structured_io, opener)
      result = StructuredIO.read_to(structured_io, opener, 15_000)
      result_byte_size = byte_size(result)
      assert result_byte_size == 20_000_000

      end_of_result =
        binary_part(
          result,
          result_byte_size - byte_size(opener),
          byte_size(opener)
        )

      assert end_of_result != opener
    end
  end
end
