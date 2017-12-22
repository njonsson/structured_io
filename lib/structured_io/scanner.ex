defmodule StructuredIO.Scanner do
  @moduledoc """
  Provides functions for decomposing structured data, such as markup or
  binary-encoded data.
  """


  require Logger


  @typedoc """
  The data matched in a scan.
  """
  @type match :: binary

  @typedoc """
  The data remaining after the `t:match/0` in a scan.
  """
  @type remaining :: binary


  @doc """
  Reads from the specified `scan_data` beginning with the specified `from_data`
  and ending with the specified `through_data`.

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
  @spec scan_across(binary, binary, binary) :: {match, remaining} | nil

  def scan_across(""=_scan_data, _from_data, _through_data), do: nil

  def scan_across(_scan_data, ""=_from_data, _through_data), do: nil

  def scan_across(_scan_data, _from_data, ""=_through_data), do: nil

  def scan_across(scan_data, from_data, through_data) do
    from_data_size = byte_size(from_data)
    if binary_part(scan_data, 0, from_data_size) == from_data do
      rest = binary_part(scan_data,
                         from_data_size,
                         byte_size(scan_data) - from_data_size)
      case scan_through(rest, through_data) do
        nil -> nil
        {scanned_through, after_through} ->
          {from_data <> scanned_through, after_through}
      end
    end
  end


  @spec scan(binary, binary, binary) :: {binary | nil, match, remaining} | nil

  defp scan(_, "", _), do: nil

  defp scan(previously_scanned_data, scan_data, through_data) do
    scan_data_size = byte_size(scan_data)
    through_data_size = byte_size(through_data)
    if scan_data_size < through_data_size do
      nil
    else
      scanned = binary_part(scan_data, 0, through_data_size)
      if scanned == through_data do
        rest = binary_part(scan_data,
                           through_data_size,
                           byte_size(scan_data) - through_data_size)
        {nil, previously_scanned_data <> scanned, rest}
      else
        first = binary_part(scan_data, 0, 1)
        rest = binary_part(scan_data, 1, byte_size(scan_data) - 1)
        case scan(previously_scanned_data <> first, rest, through_data) do
          nil   -> nil
          other -> other
        end
      end
    end
  end


  @spec scan_through(binary, binary) :: {match, remaining} | nil

  defp scan_through(""=_scan_data, _through_data), do: nil

  defp scan_through(_scan_data, ""=_through_data), do: nil

  defp scan_through(scan_data, through_data) do
    case scan("", scan_data, through_data) do
      nil              -> nil
      {_, match, rest} -> {match, rest}
    end
  end
end
