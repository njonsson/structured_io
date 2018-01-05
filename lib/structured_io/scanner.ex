defmodule StructuredIO.Scanner do
  @moduledoc """
  Provides functions for decomposing structured data, such as markup or
  binary-encoded data.
  """


  @typedoc """
  A binary value which marks the beginning of an enclosed data element.
  """
  @type left :: binary


  @typedoc """
  The portion of a binary value matched in a scan.
  """
  @type match :: binary


  @typedoc """
  The portion of a binary value remaining after the `t:match/0` in a scan.
  """
  @type remainder :: binary


  @typedoc """
  A binary value which marks the end of an enclosed or terminated data element.
  """
  @type right :: binary


  @doc """
  Reads from the specified `data` beginning with the specified `left` and ending
  with the specified `right`, inclusive.

  If `data` does not both begin with `left` and contain `right`, the result is
  `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_across "<elem>foo</elem",
      ...>                                  "<elem>",
      ...>                                  "</elem>"
      nil

      iex> StructuredIO.Scanner.scan_across "<elem>foo</elem><elem>bar</elem>",
      ...>                                  "<elem>",
      ...>                                  "</elem>"
      {"<elem>foo</elem>",
       "<elem>bar</elem>"}

      iex> StructuredIO.Scanner.scan_across <<0, 0, 0, 1, 2, 3, 255, 255>>,
      ...>                                  <<0, 0, 0>>,
      ...>                                  <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_across <<0, 0, 0, 1, 2, 3, 255, 255, 255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>,
      ...>                                  <<0, 0, 0>>,
      ...>                                  <<255, 255, 255>>
      {<<0, 0, 0, 1, 2, 3, 255, 255, 255>>,
       <<0, 0, 0, 4, 5, 6, 255, 255, 255>>}
  """
  @spec scan_across(binary, left, right) :: {match, remainder} | nil

  def scan_across(""=_data, _left, _right), do: nil

  def scan_across(_data, ""=_left, _right), do: nil

  def scan_across(_data, _left, ""=_right), do: nil

  def scan_across(data, left, right) do
    left_size = byte_size(left)
    if left_size <= byte_size(data) do
      <<data_beginning::binary-size(left_size), data_after_left::binary>> = data
      if data_beginning == left do
        with {scanned_through,
              remainder} <- scan_through(data_after_left, right) do
          {left <> scanned_through, remainder}
        end
      end
    end
  end


  @doc """
  Reads from the specified `data` beginning with the specified `left` and ending
  with the specified `right`, exclusive.

  If `data` does not both begin with `left` and contain `right`, the result is
  `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_between "<elem>foo</elem",
      ...>                                   "<elem>",
      ...>                                   "</elem>"
      nil

      iex> StructuredIO.Scanner.scan_between "<elem>foo</elem><elem>bar</elem>",
      ...>                                   "<elem>",
      ...>                                   "</elem>"
      {"foo",
       "<elem>bar</elem>"}

      iex> StructuredIO.Scanner.scan_between <<0, 0, 0, 1, 2, 3, 255, 255>>,
      ...>                                   <<0, 0, 0>>,
      ...>                                   <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_between <<0, 0, 0, 1, 2, 3, 255, 255, 255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>,
      ...>                                   <<0, 0, 0>>,
      ...>                                   <<255, 255, 255>>
      {<<1, 2, 3>>,
       <<0, 0, 0, 4, 5, 6, 255, 255, 255>>}
  """
  @spec scan_between(binary, left, right) :: {match, remainder} | nil

  def scan_between(""=_data, _left, _right), do: nil

  def scan_between(_data, ""=_left, _right), do: nil

  def scan_between(_data, _left, ""=_right), do: nil

  def scan_between(data, left, right) do
    left_size = byte_size(left)
    if left_size <= byte_size(data) do
      <<data_beginning::binary-size(left_size), data_after_left::binary>> = data
      if data_beginning == left do
        with {match, right_plus_remainder} <- scan_to(data_after_left, right) do
          right_size = byte_size(right)
          <<_::binary-size(right_size),
            remainder::binary>> = right_plus_remainder
          {match, remainder}
        end
      end
    end
  end


  @doc """
  Reads from the specified `data` if and until the specified `right` is
  encountered, including `right`.

  If `data` does not contain `right`, the result is `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_through "foo<br /",
      ...>                                   "<br/>"
      nil

      iex> StructuredIO.Scanner.scan_through "foo<br/>bar<br/>",
      ...>                                   "<br/>"
      {"foo<br/>",
       "bar<br/>"}

      iex> StructuredIO.Scanner.scan_through <<1, 2, 3, 255, 255>>,
      ...>                                   <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_through <<1, 2, 3, 255, 255, 255, 4, 5, 6, 255, 255, 255>>,
      ...>                                   <<255, 255, 255>>
      {<<1, 2, 3, 255, 255, 255>>,
       <<4, 5, 6, 255, 255, 255>>}
  """
  @spec scan_through(binary, right) :: {match, remainder} | nil

  def scan_through(""=_data, _right), do: nil

  def scan_through(_data, ""=_right), do: nil

  def scan_through(data, right) do
    with {match, remainder} <- scan("", data, right) do
      {match <> right, remainder}
    end
  end


  @doc """
  Reads from the specified `data` if and until the specified `right` is
  encountered, excluding `right`.

  If `data` does not contain `right`, the result is `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_to "foo<br /",
      ...>                              "<br/>"
      nil

      iex> StructuredIO.Scanner.scan_to "foo<br/>bar<br/>",
      ...>                              "<br/>"
      {"foo",
       "<br/>bar<br/>"}

      iex> StructuredIO.Scanner.scan_to <<1, 2, 3, 255, 255>>,
      ...>                              <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_to <<1, 2, 3, 255, 255, 255, 4, 5, 6, 255, 255, 255>>,
      ...>                              <<255, 255, 255>>
      {<<1, 2, 3>>,
       <<255, 255, 255, 4, 5, 6, 255, 255, 255>>}
  """
  @spec scan_to(binary, right) :: {match, remainder} | nil

  def scan_to(""=_data, _right), do: nil

  def scan_to(_data, ""=_right), do: nil

  def scan_to(data, right) do
    with {match, remainder} <- scan("", data, right) do
      {match, right <> remainder}
    end
  end


  @spec scan(binary, binary, binary) :: {binary, binary} | nil

  defp scan(_, "", _), do: nil

  defp scan(before, scanning, scanning_for) do
    scanning_size = byte_size(scanning)
    scanning_for_size = byte_size(scanning_for)
    unless scanning_size < scanning_for_size do
      <<scanned::binary-size(scanning_for_size),
        after_scanning_for::binary>> = scanning
      if scanned == scanning_for do
        {before, after_scanning_for}
      else
        <<scanning_first::binary-size(1), scanning_rest::binary>> = scanning
        scan((before <> scanning_first), scanning_rest, scanning_for)
      end
    end
  end
end
