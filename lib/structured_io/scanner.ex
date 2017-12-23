defmodule StructuredIO.Scanner do
  @moduledoc """
  Provides functions for decomposing structured data, such as markup or
  binary-encoded data.
  """


  @typedoc """
  The data matched in a scan.
  """
  @type match :: binary

  @typedoc """
  The data remaining after the `t:match/0` in a scan.
  """
  @type remainder :: binary


  @doc """
  Reads from the specified `scan_data` beginning with the specified `from_data`
  and ending with the specified `through_data`, inclusive.

  If `scan_data` does not both begin with `from_data` and contain
  `through_data`, the result is `nil`.

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
  @spec scan_across(binary, binary, binary) :: {match, remainder} | nil

  def scan_across(""=_scan_data, _from_data, _through_data), do: nil

  def scan_across(_scan_data, ""=_from_data, _through_data), do: nil

  def scan_across(_scan_data, _from_data, ""=_through_data), do: nil

  def scan_across(scan_data, from_data, through_data) do
    from_data_size = byte_size(from_data)
    <<scan_data_beginning::binary-size(from_data_size),
      scan_data_after_from::binary>> = scan_data
    if scan_data_beginning == from_data do
      with {scanned_through,
            after_through_data} <- scan_through(scan_data_after_from,
                                                through_data) do
        {from_data <> scanned_through, after_through_data}
      end
    end
  end


  @doc """
  Reads from the specified `scan_data` if and until the specified `through_data`
  is encountered, including `through_data`.

  If `scan_data` does not contain `through_data`, the result is `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_through "foo<br /",
      ...>                                   "<br />"
      nil

      iex> StructuredIO.Scanner.scan_through "foo<br />bar<br />",
      ...>                                   "<br />"
      {"foo<br />",
       "bar<br />"}

      iex> StructuredIO.Scanner.scan_through <<1, 2, 3, 255, 255>>,
      ...>                                   <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_through <<1, 2, 3, 255, 255, 255, 4, 5, 6, 255, 255, 255>>,
      ...>                                   <<255, 255, 255>>
      {<<1, 2, 3, 255, 255, 255>>,
       <<4, 5, 6, 255, 255, 255>>}
  """
  @spec scan_through(binary, binary) :: {match, remainder} | nil

  def scan_through(""=_scan_data, _through_data), do: nil

  def scan_through(_scan_data, ""=_through_data), do: nil

  def scan_through(scan_data, through_data) do
    with {match, remainder} <- scan("", scan_data, through_data) do
      {match <> through_data, remainder}
    end
  end


  @doc """
  Reads from the specified `scan_data` if and until the specified `to_data` is
  encountered, excluding `to_data`.

  If `scan_data` does not contain `to_data`, the result is `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_to "foo</elem><elem",
      ...>                              "<elem>"
      nil

      iex> StructuredIO.Scanner.scan_to "foo</elem><elem>bar</elem><elem>baz",
      ...>                              "<elem>"
      {"foo</elem>",
       "<elem>bar</elem><elem>baz"}

      iex> StructuredIO.Scanner.scan_to <<1, 2, 3, 255, 255, 255, 0, 0>>,
      ...>                              <<0, 0, 0>>
      nil

      iex> StructuredIO.Scanner.scan_to <<1, 2, 3, 255, 255, 255, 0, 0, 0, 4, 5, 6, 255, 255, 255, 0, 0, 0, 7, 8, 9>>,
      ...>                              <<0, 0, 0>>
      {<<1, 2, 3, 255, 255, 255>>,
       <<0, 0, 0, 4, 5, 6, 255, 255, 255, 0, 0, 0, 7, 8, 9>>}
  """
  @spec scan_to(binary, binary) :: {match, remainder} | nil

  def scan_to(""=_scan_data, _to_data), do: nil

  def scan_to(_scan_data, ""=_to_data), do: nil

  def scan_to(scan_data, to_data) do
    with {match, remainder} <- scan("", scan_data, to_data) do
      {match, to_data <> remainder}
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
