defmodule StructuredIO.Scanner do
  @moduledoc """
  Provides functions for decomposing structured data, such as markup or
  binary-encoded data.
  """

  defmodule Enclosed do
    @moduledoc false

    alias StructuredIO.Scanner

    @enforce_keys ~w{data left right count}a
    defstruct before: "", data: nil, left: nil, right: nil, count: nil

    @typedoc false
    @type t :: %__MODULE__{
            before: binary,
            data: binary,
            left: Scanner.left(),
            right: Scanner.right(),
            count: non_neg_integer
          }
  end

  defmodule Measured do
    @moduledoc false

    alias StructuredIO.Scanner

    @enforce_keys ~w{data unit count}a
    defstruct before: "", data: nil, unit: nil, count: nil

    @typedoc false
    @type t :: %__MODULE__{
            before: binary,
            data: binary,
            unit: Scanner.unit(),
            count: Scanner.count()
          }
  end

  defmodule Terminated do
    @moduledoc false

    alias StructuredIO.Scanner

    @enforce_keys [:data, :right]
    defstruct before: "", data: nil, right: nil

    @typedoc false
    @type t :: %__MODULE__{before: binary, data: binary, right: Scanner.right()}
  end

  @typedoc """
  A measure of size for a measured data element. See `t:unit/0`.
  """
  @type count :: non_neg_integer

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

  @typedoc """
  The unit of size for a measured data element: either bytes or graphemes. See
  `t:count/0`.
  """
  @type unit :: :bytes | :graphemes

  @valid_units [:bytes, :graphemes]

  @doc """
  Reads from the specified `data` in the specified quantity. The quantity is
  measured as a `count` of a particular `unit`.

  If the process does not contain at least the expected quantity of data, the
  result is `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan "\\r\\nfoo",
      ...>                           :graphemes,
      ...>                           5
      nil

      iex> StructuredIO.Scanner.scan "\\r\\nfoo\\tbar",
      ...>                           :graphemes,
      ...>                           5
      {"\\r\\nfoo\\t",
       "bar"}

      iex> StructuredIO.Scanner.scan <<23, 45>>,
      ...>                           :bytes,
      ...>                           3
      nil

      iex> StructuredIO.Scanner.scan <<23, 45, 67, 89>>,
      ...>                           :bytes,
      ...>                           3
      {<<23, 45, 67>>,
       <<89>>}
  """
  @doc since: "0.8.0"
  @spec scan(binary, unit, count) :: {match, remainder} | nil

  def scan(_data, unit, 0 = _count) when unit in @valid_units, do: nil

  def scan(
        "" = _data,
        unit,
        count
      )
      when unit in @valid_units and is_integer(count) and 0 <= count do
    nil
  end

  def scan(
        data,
        unit,
        count
      )
      when unit in @valid_units and is_integer(count) and 0 <= count do
    scan(%Measured{data: data, unit: unit, count: count})
  end

  @doc """
  Reads from the specified `data`, beginning with the specified `left` and
  ending with the occurrence of the specified `right` that corresponds to it,
  inclusive.

  If `data` does not both begin with `left` and contain a corresponding `right`,
  the result is `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_across "<elem>foo</elem",
      ...>                                  "<elem>",
      ...>                                  "</elem>"
      nil

      iex> StructuredIO.Scanner.scan_across "<elem>foo<elem>bar</elem></elem>baz",
      ...>                                  "<elem>",
      ...>                                  "</elem>"
      {"<elem>foo<elem>bar</elem></elem>",
       "baz"}

      iex> StructuredIO.Scanner.scan_across <<0, 0, 0, 1, 2, 3, 255, 255>>,
      ...>                                  <<0, 0, 0>>,
      ...>                                  <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_across <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255, 255, 7, 8, 9>>,
      ...>                                  <<0, 0, 0>>,
      ...>                                  <<255, 255, 255>>
      {<<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255, 255>>,
       <<7, 8, 9>>}
  """
  @doc since: "0.1.0"
  @spec scan_across(binary, left, right) :: {match, remainder} | nil

  def scan_across("" = _data, _left, _right), do: nil

  def scan_across(_data, "" = _left, _right), do: nil

  def scan_across(_data, _left, "" = _right), do: nil

  def scan_across(data, left, right) do
    with data_after_left when is_binary(data_after_left) <-
           after_beginning(data, left),
         {match, remainder} <-
           scan(%Enclosed{
             data: data_after_left,
             left: left,
             right: right,
             count: 1
           }) do
      {left <> match, remainder}
    end
  end

  @doc """
  Reads from the specified `data`, beginning with the specified `left` and
  ending with the first occurrence of the specified `right`, inclusive.

  If `data` does not both begin with `left` and contain `right`, the result is
  `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_across_ignoring_overlap "<elem>foo<elem>bar</elem",
      ...>                                                   "<elem>",
      ...>                                                   "</elem>"
      nil

      iex> StructuredIO.Scanner.scan_across_ignoring_overlap "<elem>foo<elem>bar</elem></elem>baz",
      ...>                                                   "<elem>",
      ...>                                                   "</elem>"
      {"<elem>foo<elem>bar</elem>",
       "</elem>baz"}

      iex> StructuredIO.Scanner.scan_across_ignoring_overlap <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255>>,
      ...>                                                   <<0, 0, 0>>,
      ...>                                                   <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_across_ignoring_overlap <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255, 255, 7, 8, 9>>,
      ...>                                                   <<0, 0, 0>>,
      ...>                                                   <<255, 255, 255>>
      {<<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255>>,
       <<255, 255, 255, 7, 8, 9>>}
  """
  @doc since: "0.7.0"
  @spec scan_across_ignoring_overlap(
          binary,
          left,
          right
        ) :: {match, remainder} | nil

  def scan_across_ignoring_overlap("" = _data, _left, _right), do: nil

  def scan_across_ignoring_overlap(_data, "" = _left, _right), do: nil

  def scan_across_ignoring_overlap(_data, _left, "" = _right), do: nil

  def scan_across_ignoring_overlap(data, left, right) do
    with data_after_left when is_binary(data_after_left) <-
           after_beginning(data, left),
         {match, remainder} <-
           scan_through(data_after_left, right) do
      {left <> match, remainder}
    end
  end

  @doc """
  Reads from the specified `data`, beginning with the specified `left` and
  ending with the occurrence of the specified `right` that corresponds to it,
  exclusive.

  If `data` does not both begin with `left` and contain a corresponding `right`,
  the result is `nil`.

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

      iex> StructuredIO.Scanner.scan_between "<elem>foo<elem>bar</elem></elem>baz",
      ...>                                   "<elem>",
      ...>                                   "</elem>"
      {"foo<elem>bar</elem>",
       "baz"}

      iex> StructuredIO.Scanner.scan_between <<0, 0, 0, 1, 2, 3, 255, 255>>,
      ...>                                   <<0, 0, 0>>,
      ...>                                   <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_between <<0, 0, 0, 1, 2, 3, 255, 255, 255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>,
      ...>                                   <<0, 0, 0>>,
      ...>                                   <<255, 255, 255>>
      {<<1, 2, 3>>,
       <<0, 0, 0, 4, 5, 6, 255, 255, 255>>}

      iex> StructuredIO.Scanner.scan_between <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255, 255, 7, 8, 9>>,
      ...>                                   <<0, 0, 0>>,
      ...>                                   <<255, 255, 255>>
      {<<1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255>>,
       <<7, 8, 9>>}
  """
  @doc since: "0.4.0"
  @spec scan_between(binary, left, right) :: {match, remainder} | nil

  def scan_between("" = _data, _left, _right), do: nil

  def scan_between(_data, "" = _left, _right), do: nil

  def scan_between(_data, _left, "" = _right), do: nil

  def scan_between(data, left, right) do
    with data_after_left when is_binary(data_after_left) <-
           after_beginning(data, left),
         {match, remainder} <-
           scan(%Enclosed{
             data: data_after_left,
             left: left,
             right: right,
             count: 1
           }) do
      match_without_right =
        binary_part(
          match,
          0,
          byte_size(match) - byte_size(right)
        )

      {match_without_right, remainder}
    end
  end

  @doc """
  Reads from the specified `data`, beginning with the specified `left` and
  ending with the first occurrence of the specified `right`, exclusive.

  If `data` does not both begin with `left` and contain `right`, the result is
  `nil`.

  ## Examples

      iex> StructuredIO.Scanner.scan_between_ignoring_overlap "<elem>foo<elem>bar</elem",
      ...>                                                    "<elem>",
      ...>                                                    "</elem>"
      nil

      iex> StructuredIO.Scanner.scan_between_ignoring_overlap "<elem>foo<elem>bar</elem></elem>baz",
      ...>                                                    "<elem>",
      ...>                                                    "</elem>"
      {"foo<elem>bar",
       "</elem>baz"}

      iex> StructuredIO.Scanner.scan_between_ignoring_overlap <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255>>,
      ...>                                                    <<0, 0, 0>>,
      ...>                                                    <<255, 255, 255>>
      nil

      iex> StructuredIO.Scanner.scan_between_ignoring_overlap <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255, 255, 7, 8, 9>>,
      ...>                                                    <<0, 0, 0>>,
      ...>                                                    <<255, 255, 255>>
      {<<1, 2, 3, 0, 0, 0, 4, 5, 6>>,
       <<255, 255, 255, 7, 8, 9>>}
  """
  @doc since: "0.7.0"
  @spec scan_between_ignoring_overlap(
          binary,
          left,
          right
        ) :: {match, remainder} | nil

  def scan_between_ignoring_overlap("" = _data, _left, _right), do: nil

  def scan_between_ignoring_overlap(_data, "" = _left, _right), do: nil

  def scan_between_ignoring_overlap(_data, _left, "" = _right), do: nil

  def scan_between_ignoring_overlap(data, left, right) do
    with data_after_left when is_binary(data_after_left) <-
           after_beginning(data, left) do
      scan(%Terminated{data: data_after_left, right: right})
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
  @doc since: "0.2.0"
  @spec scan_through(binary, right) :: {match, remainder} | nil

  def scan_through("" = _data, _right), do: nil

  def scan_through(_data, "" = _right), do: nil

  def scan_through(data, right) do
    with {match, remainder} <- scan(%Terminated{data: data, right: right}) do
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
  @doc since: "0.2.0"
  @spec scan_to(binary, right) :: {match, remainder} | nil

  def scan_to("" = _data, _right), do: nil

  def scan_to(_data, "" = _right), do: nil

  def scan_to(data, right) do
    with {match, remainder} <- scan(%Terminated{data: data, right: right}) do
      {match, right <> remainder}
    end
  end

  @spec after_beginning(binary, binary) :: binary | nil
  defp after_beginning(data, beginning) do
    beginning_size = byte_size(beginning)

    if beginning_size <= byte_size(data) do
      <<data_beginning::binary-size(beginning_size), data_after_beginning::binary>> = data

      if data_beginning == beginning do
        data_after_beginning
      end
    end
  end

  @spec scan(Enclosed.t() | Measured.t() | Terminated.t()) :: {binary, binary} | nil

  defp scan(%Enclosed{before: before, data: data, count: 0}), do: {before, data}

  defp scan(%Enclosed{data: ""}), do: nil

  defp scan(
         %Enclosed{
           before: before,
           data: data,
           left: left,
           right: right,
           count: count
         } = arguments
       ) do
    case after_beginning(data, left) do
      nil ->
        case after_beginning(data, right) do
          nil ->
            <<data_first::binary-size(1), data_rest::binary>> = data
            scan(%{arguments | before: before <> data_first, data: data_rest})

          after_right ->
            scan(%{
              arguments
              | before: before <> right,
                data: after_right,
                count: count - 1
            })
        end

      after_left ->
        scan(%{
          arguments
          | before: before <> left,
            data: after_left,
            count: count + 1
        })
    end
  end

  defp scan(%Enclosed{} = arguments), do: scan(%{arguments | before: ""})

  defp scan(%Measured{before: before, data: data, count: 0}), do: {before, data}

  defp scan(%Measured{data: ""}), do: nil

  defp scan(%Measured{data: data, unit: :bytes, count: count}) do
    if count <= byte_size(data) do
      <<match::binary-size(count), remainder::binary>> = data
      {match, remainder}
    end
  end

  defp scan(
         %Measured{
           before: before,
           data: data,
           unit: :graphemes,
           count: count
         } = arguments
       ) do
    case String.next_grapheme(data) do
      {match, remaining} ->
        scan(%{
          arguments
          | before: before <> match,
            data: remaining,
            count: count - 1
        })

      nil ->
        {before, data}
    end
  end

  defp scan(%Terminated{data: ""}), do: nil

  defp scan(%Terminated{before: before, data: data, right: right} = arguments) do
    data_size = byte_size(data)
    right_size = byte_size(right)

    if right_size <= data_size do
      <<data_beginning::binary-size(right_size), after_right::binary>> = data

      if data_beginning == right do
        {before, after_right}
      else
        <<data_first::binary-size(1), data_rest::binary>> = data
        scan(%{arguments | before: before <> data_first, data: data_rest})
      end
    end
  end
end
