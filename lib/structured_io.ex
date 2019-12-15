defmodule StructuredIO do
  @moduledoc """
  A process for performing I/O of structured data, such as markup or
  binary-encoded data.

  ## Encoding

  The process operates in either **binary mode** or **Unicode mode** (see
  `start/2` and `start_link/2`). When in binary mode, the result of a read
  operation is a binary, regardless of whether the data read is
  `String.valid?/1`. In Unicode mode, the result of a read operation is an
  `t:error/0` if the data read is not properly encoded Unicode data.
  """

  defmodule State do
    @moduledoc false

    defstruct data: [], mode: nil

    @typedoc false
    @type t :: %__MODULE__{
            data: iodata | IO.chardata() | String.Chars.t(),
            mode: nil | StructuredIO.mode()
          }
  end

  use GenServer

  @impl true
  use StructuredIO.GenServerTransaction,
    function_name: "read_complex",
    server_name: "structured_io",
    commit_instruction: :ok,
    since: "0.9.0",
    append_to_doc: """

    ## Examples

    In the following example, a Tag-Length-Value data element is composed of:

    * A fixed-length Tag expression between `<<1>>` and `<<255>>` (one byte)
    * A fixed-length Length expression between 0 and 255 (one byte)
    * A variable-length Value expression whose length is the Length

    Following the convention of built-in functions such as `read_across/4`, if
    the whole element is not present then the result of the operation is an empty
    binary (`""`).

        iex> {:ok,
        ...>  structured_io} = StructuredIO.start_link(:binary)
        iex> read_tag_length_value = fn s ->
        ...>   with tag
        ...>          when not (tag in ["", <<0>>])
        ...>          <- StructuredIO.read(s, 1),
        ...>        <<length::size(8)>>
        ...>          <- StructuredIO.read(s, 1),
        ...>        value
        ...>          when (length == 0) or
        ...>               (value != "")
        ...>          <- StructuredIO.read(s, length) do
        ...>     {:ok,
        ...>      %{tag: tag,
        ...>        length: length,
        ...>        value: value}}
        ...>   end
        ...> end
        iex> StructuredIO.read_complex structured_io,
        ...>                           read_tag_length_value
        ""
        iex> StructuredIO.write structured_io,
        ...>                    <<111>>
        iex> StructuredIO.read_complex structured_io,
        ...>                           read_tag_length_value
        ""
        iex> StructuredIO.write structured_io,
        ...>                    0
        iex> StructuredIO.read_complex structured_io,
        ...>                           read_tag_length_value
        %{tag: <<111>>,
          length: 0,
          value: ""}
        iex> StructuredIO.read_complex structured_io,
        ...>                           read_tag_length_value
        ""
        iex> StructuredIO.write structured_io,
        ...>                    <<222>>
        iex> StructuredIO.write structured_io,
        ...>                    byte_size("foo")
        iex> StructuredIO.write structured_io,
        ...>                    "foo"
        iex> StructuredIO.read_complex structured_io,
        ...>                           read_tag_length_value
        %{tag: <<222>>,
          length: 3,
          value: "foo"}
        iex> StructuredIO.read_complex structured_io,
        ...>                           read_tag_length_value
        ""
    """

  @behaviour StructuredIO.Behaviour

  alias StructuredIO.{Collector, Deprecated, Enumerator, Scanner}

  @typedoc """
  A number of bytes or graphemes in a measured data element.
  """
  @type count :: Scanner.count()

  @typedoc """
  An error result.
  """
  @type error :: {:error, atom | binary}

  @typedoc """
  A binary value which marks the beginning of an enclosed data element.
  """
  @type left :: Scanner.left()

  @typedoc """
  The portion of a binary value matched in a read operation.
  """
  @type match :: Scanner.match()

  @typedoc """
  A mode of operation for the process: either binary or Unicode.
  """
  @type mode :: :binary | :unicode

  @valid_modes [:binary, :unicode]

  @typedoc """
  A binary value which marks the end of an enclosed or terminated data element.
  """
  @type right :: Scanner.right()

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.read_across in binary mode instead"
  defdelegate binread_across(
                structured_io,
                left,
                right,
                timeout \\ 5000
              ),
              to: Deprecated

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.read_between in binary mode instead"
  defdelegate binread_between(
                structured_io,
                left,
                right,
                timeout \\ 5000
              ),
              to: Deprecated

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.read_through in binary mode instead"
  defdelegate binread_through(
                structured_io,
                right,
                timeout \\ 5000
              ),
              to: Deprecated

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.read_to in binary mode instead"
  defdelegate binread_to(structured_io, to, timeout \\ 5000), to: Deprecated

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.write in binary mode instead"
  defdelegate binwrite(structured_io, iodata), to: Deprecated

  @doc """
  Returns a value that can be passed to `Enum.into/2` or `Enum.into/3` for
  writing data to the specified `structured_io`.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""
      iex> collector = StructuredIO.collect(structured_io)
      iex> ["<elem>foo</elem>",
      ...>  "<elem>bar</elem>",
      ...>  "<elem>baz</elem>"]
      iex> |> Enum.into(collector)
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      "foo"
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      "bar"
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      "baz"
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""
  """
  @doc since: "0.6.0"
  @impl true
  @spec collect(GenServer.server()) :: Collector.t()
  def collect(structured_io) do
    {:ok, collector} = Collector.new(%{process: structured_io, function: :write})
    collector
  end

  @doc """
  Returns a value that can be passed to functions such as `Enum.map/2` for
  reading data elements from the specified `structured_io`, using the specified
  `#{inspect(__MODULE__)}` `function`, and the specified `left` and/or
  `right`/`operation`.

  Note that enumeration is not a purely functional operation; it consumes data
  elements from the underlying `#{inspect(__MODULE__)}` process.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo</elem>"
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>bar</elem>"
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>baz</elem>"
      :ok
      iex> structured_io
      ...> |> StructuredIO.enumerate_with(:read_between,
      ...>                                "<elem>",
      ...>                                "</elem>")
      ...> |> StructuredIO.Enumerator.timeout(60_000)
      ...> |> Enum.map(&String.upcase/1)
      ["FOO",
       "BAR",
       "BAZ"]
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "foo<br/>"
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "bar<br/>"
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "baz<br/>"
      :ok
      iex> structured_io
      ...> |> StructuredIO.enumerate_with(:read_through,
      ...>                                "<br/>")
      ...> |> StructuredIO.Enumerator.timeout(:infinity)
      ...> |> Enum.map(&String.upcase/1)
      ["FOO<BR/>",
       "BAR<BR/>",
       "BAZ<BR/>"]
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br />"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> read_tag_length_value = fn s ->
      ...>   with tag
      ...>          when not (tag in ["", <<0>>])
      ...>          <- StructuredIO.read(s, 1),
      ...>        <<length::size(8)>>
      ...>          <- StructuredIO.read(s, 1),
      ...>        value
      ...>          when (length == 0) or
      ...>               (value != "")
      ...>          <- StructuredIO.read(s, length) do
      ...>     {:ok,
      ...>      %{tag: tag,
      ...>        length: length,
      ...>        value: value}}
      ...>   end
      ...> end
      iex> StructuredIO.write structured_io,
      ...>                    <<111, 0, 222, 3, "foo">>
      :ok
      iex> structured_io
      ...> |> StructuredIO.enumerate_with(:read_complex,
      ...>                                read_tag_length_value)
      ...> |> Enum.into([])
      [%{tag: <<111>>,
         length: 0,
         value: ""},
       %{tag: <<222>>,
         length: 3,
         value: "foo"}]
      iex> StructuredIO.read_complex structured_io,
      ...>                           read_tag_length_value
      ""

  To override the default per-element timeout of a `read*` function, call
  `StructuredIO.Enumerator.timeout/2` as shown above.
  """

  @doc since: "0.6.0"
  @impl true
  @spec enumerate_with(
          GenServer.server(),
          :read_across
          | :read_across_ignoring_overlap
          | :read_between
          | :read_between_ignoring_overlap,
          left,
          right
        ) :: Enumerator.t()
  def enumerate_with(
        structured_io,
        function,
        left,
        right
      )
      when function in ~w{
        read_across
        read_across_ignoring_overlap
        read_between
        read_between_ignoring_overlap
      }a do
    {:ok, enumerator} =
      Enumerator.new(%{
        process: structured_io,
        function: function,
        additional_arguments: [left, right]
      })

    enumerator
  end

  @doc since: "0.6.0"
  @impl true
  @spec enumerate_with(
          GenServer.server(),
          :read_through | :read_to,
          right
        ) :: Enumerator.t()
  def enumerate_with(
        structured_io,
        function,
        right_or_operation
      )
      when function in [:read_through, :read_to] and
             is_binary(right_or_operation) do
    {:ok, enumerator} =
      Enumerator.new(%{
        process: structured_io,
        function: function,
        additional_arguments: right_or_operation
      })

    enumerator
  end

  @doc since: "0.10.0"
  @impl true
  @spec enumerate_with(
          GenServer.server(),
          :read_complex,
          operation
        ) :: Enumerator.t()
  def enumerate_with(
        structured_io,
        :read_complex = function,
        right_or_operation
      )
      when is_function(right_or_operation) do
    {:ok, enumerator} =
      Enumerator.new(%{
        process: structured_io,
        function: function,
        additional_arguments: right_or_operation
      })

    enumerator
  end

  @doc """
  Gets the mode of the specified `structured_io`.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.mode structured_io
      :binary

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.mode structured_io
      :unicode
  """
  @doc since: "0.5.0"
  @impl true
  @spec mode(GenServer.server()) :: mode
  def mode(structured_io) do
    request = :mode
    GenServer.call(structured_io, request)
  end

  @doc """
  Reads data from the specified `structured_io` in the specified quantity, or
  beginning with the specified binary value. In binary mode, a numeric
  `count_or_match` denotes a number of bytes; in Unicode mode, a numeric
  `count_or_match` denotes a number of graphemes.

  If the data in the process does not contain at least the expected (quantity of)
  data, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<23, 45>>
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   3
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<67>>
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   3
      <<23, 45, 67>>
      iex> StructuredIO.read structured_io,
      ...>                   3
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "\\r\\nfo"
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   4
      ""
      iex> StructuredIO.write structured_io,
      ...>                    "o"
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   4
      "\\r\\nfoo"
      iex> StructuredIO.read structured_io,
      ...>                   4
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "fo"
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   "foo"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    "obar"
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   "foo"
      "foo"
      iex> StructuredIO.read structured_io,
      ...>                   "foo"
      ""
      iex> StructuredIO.read structured_io,
      ...>                   "bar"
      "bar"
      iex> StructuredIO.read structured_io,
      ...>                   "bar"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   4
      ""
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   4
      "😕"
      iex> StructuredIO.read structured_io,
      ...>                   4
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   "😕"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   "😕"
      "😕"
      iex> StructuredIO.read structured_io,
      ...>                   "😕"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   1
      {:error,
       "UnicodeConversionError: incomplete encoding starting at \#{inspect fragment1}"}
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   1
      "😕"
      iex> StructuredIO.read structured_io,
      ...>                   1
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   "😕"
      {:error,
       "UnicodeConversionError: incomplete encoding starting at \#{inspect fragment1}"}
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.read structured_io,
      ...>                   "😕"
      "😕"
      iex> StructuredIO.read structured_io,
      ...>                   "😕"
      ""

  See `mode/1`.
  """
  @doc since: "0.8.0"
  @impl true
  @spec read(GenServer.server(), count | match, timeout) :: match | error
  def read(structured_io, count_or_match, timeout \\ 5000) do
    request = {:read, count_or_match}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the occurrence of the specified `right` that
  corresponds to it, inclusive.

  If the data in the process does not both begin with `left` and contain a
  corresponding `right`, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255, 0, 0, 0, 7, 8, 9, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255, 255>>
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      <<0, 0, 0, 7, 8, 9, 255, 255, 255>>
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo<elem>bar</elem></elem"
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    "><elem>baz</elem>"
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      "<elem>foo<elem>bar</elem></elem>"
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      "<elem>baz</elem>"
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>"
      :ok
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "</elem>"
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      "<elem>😕</elem>"
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>"
      :ok
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      {:error,
       "UnicodeConversionError: incomplete encoding starting at \#{inspect fragment1}"}
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "</elem>"
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      "<elem>😕</elem>"
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      ""
  """
  @doc since: "0.1.0"
  @impl true
  @spec read_across(GenServer.server(), left, right, timeout) :: match | error
  def read_across(structured_io, left, right, timeout \\ 5000) do
    request = {:read_across, left, right}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the first occurrence of the specified `right`,
  inclusive.

  If the data in the process does not both begin with `left` and contain `right`,
  the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255>>
      :ok
      iex> StructuredIO.read_across_ignoring_overlap structured_io,
      ...>                                           <<0, 0, 0>>,
      ...>                                           <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255>>
      :ok
      iex> StructuredIO.read_across_ignoring_overlap structured_io,
      ...>                                           <<0, 0, 0>>,
      ...>                                           <<255, 255, 255>>
      <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255>>

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo<elem>bar</elem"
      :ok
      iex> StructuredIO.read_across_ignoring_overlap structured_io,
      ...>                                           "<elem>",
      ...>                                           "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    ">"
      :ok
      iex> StructuredIO.read_across_ignoring_overlap structured_io,
      ...>                                           "<elem>",
      ...>                                           "</elem>"
      "<elem>foo<elem>bar</elem>"
  """
  @doc since: "0.7.0"
  @impl true
  @spec read_across_ignoring_overlap(
          GenServer.server(),
          left,
          right,
          timeout
        ) :: match | error
  def read_across_ignoring_overlap(
        structured_io,
        left,
        right,
        timeout \\ 5000
      ) do
    request = {:read_across_ignoring_overlap, left, right}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the occurrence of the specified `right` that
  corresponds to it, exclusive.

  If the data in the process does not both begin with `left` and contain a
  corresponding `right`, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           <<0, 0, 0>>,
      ...>                           <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255>>
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           <<0, 0, 0>>,
      ...>                           <<255, 255, 255>>
      <<1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255, 255>>

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo<elem>bar</elem></elem"
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    ">"
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      "foo<elem>bar</elem>"

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>"
      :ok
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "</elem>"
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      "😕"
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>"
      :ok
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      {:error,
       "UnicodeConversionError: incomplete encoding starting at \#{inspect fragment1}"}
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "</elem>"
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      "😕"
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""
  """
  @doc since: "0.2.0"
  @impl true
  @spec read_between(GenServer.server(), left, right, timeout) :: match | error
  def read_between(structured_io, left, right, timeout \\ 5000) do
    request = {:read_between, left, right}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the first occurrence of the specified `right`,
  exclusive.

  If the data in the process does not both begin with `left` and contain `right`,
  the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<0, 0, 0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 255, 255>>
      :ok
      iex> StructuredIO.read_between_ignoring_overlap structured_io,
      ...>                                            <<0, 0, 0>>,
      ...>                                            <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255>>
      :ok
      iex> StructuredIO.read_between_ignoring_overlap structured_io,
      ...>                                            <<0, 0, 0>>,
      ...>                                            <<255, 255, 255>>
      <<1, 2, 3, 0, 0, 0, 4, 5, 6>>

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo<elem>bar</elem"
      :ok
      iex> StructuredIO.read_between_ignoring_overlap structured_io,
      ...>                                            "<elem>",
      ...>                                            "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    ">"
      :ok
      iex> StructuredIO.read_between_ignoring_overlap structured_io,
      ...>                                            "<elem>",
      ...>                                            "</elem>"
      "foo<elem>bar"
  """
  @doc since: "0.7.0"
  @impl true
  @spec read_between_ignoring_overlap(
          GenServer.server(),
          left,
          right,
          timeout
        ) :: match | error
  def read_between_ignoring_overlap(
        structured_io,
        left,
        right,
        timeout \\ 5000
      ) do
    request = {:read_between_ignoring_overlap, left, right}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `right` is encountered, including `right`.

  If `right` is not encountered, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           <<255, 255, 255>>
      <<1, 2, 3, 255, 255, 255>>
      iex> StructuredIO.read_through structured_io,
      ...>                           <<255, 255, 255>>
      <<4, 5, 6, 255, 255, 255>>
      iex> StructuredIO.read_through structured_io,
      ...>                           <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "foo<br/"
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    ">bar<br/>"
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      "foo<br/>"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      "bar<br/>"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "<br/>"
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      "😕<br/>"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      {:error,
       "UnicodeConversionError: incomplete encoding starting at \#{inspect fragment1}"}
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "<br/>"
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      "😕<br/>"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      ""
  """
  @doc since: "0.2.0"
  @impl true
  @spec read_through(GenServer.server(), right, timeout) :: match | error
  def read_through(structured_io, right, timeout \\ 5000) do
    request = {:read_through, right}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `right` is encountered, excluding `right`.

  If `right` is not encountered, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      <<255, 255, 255>>
      <<1, 2, 3>>
      iex> StructuredIO.read_through structured_io,
      ...>                           <<255, 255, 255>>
      <<255, 255, 255>>
      iex> StructuredIO.read_to structured_io,
      ...>                      <<255, 255, 255>>
      <<4, 5, 6>>
      iex> StructuredIO.read_to structured_io,
      ...>                      <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "foo<br/"
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    ">bar<br/>"
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      "foo"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br/>"
      "<br/>"
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      "bar"
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "<br/>"
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      "😕"
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.write structured_io,
      ...>                    fragment1
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      {:error,
       "UnicodeConversionError: incomplete encoding starting at \#{inspect fragment1}"}
      iex> StructuredIO.write structured_io,
      ...>                    fragment2
      :ok
      iex> StructuredIO.write structured_io,
      ...>                    "<br/>"
      :ok
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      "😕"
      iex> StructuredIO.read_to structured_io,
      ...>                      "<br/>"
      ""
  """
  @doc since: "0.2.0"
  @impl true
  @spec read_to(GenServer.server(), right, timeout) :: match | error
  def read_to(structured_io, right, timeout \\ 5000) do
    request = {:read_to, right}

    structured_io
    |> GenServer.call(request, timeout)
    |> maybe_standardize_error
  end

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.start/1 instead"
  defdelegate start, to: Deprecated

  @doc """
  Starts a `#{inspect(__MODULE__)}` process without links (outside a supervision
  tree) with the specified `mode` and `options`.

  ## Examples

      iex> StructuredIO.start :super_pursuit_mode
      {:error,
       "invalid mode :super_pursuit_mode"}

  See `start_link/2`.
  """
  @doc since: "0.5.0"
  @impl true
  @spec start(mode, GenServer.options()) :: GenServer.on_start()
  def start(mode, options \\ []) do
    with {:ok, mode} <- compute_mode(mode, :start) do
      GenServer.start(__MODULE__, %State{mode: mode}, options)
    end
  end

  @doc false
  @deprecated "Call #{inspect(__MODULE__)}.start_link/1 instead"
  defdelegate start_link, to: Deprecated

  @doc """
  Starts a `#{inspect(__MODULE__)}` process linked to the current process with
  the specified `mode` and `options`.

  ## Examples

      iex> StructuredIO.start_link :super_pursuit_mode
      {:error,
       "invalid mode :super_pursuit_mode"}

  See `mode/1` and the `read*` functions for more examples.
  """
  @doc since: "0.5.0"
  @impl true
  @spec start_link(mode, GenServer.options()) :: GenServer.on_start()
  def start_link(mode, options \\ []) do
    with {:ok, mode} <- compute_mode(mode, :start_link) do
      GenServer.start_link(__MODULE__, %State{mode: mode}, options)
    end
  end

  @doc """
  Stops the specified `structured_io` process.
  """
  @doc since: "0.1.0"
  @impl true
  @spec stop(GenServer.server(), term, timeout) :: :ok
  def stop(structured_io, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(structured_io, reason, timeout)
  end

  @doc """
  Writes the specified `data` to the specified `structured_io`.

  No timeout is available because the operation is performed asynchronously.

  See the `read*` functions for examples.
  """
  @doc since: "0.1.0"
  @impl true
  @spec write(
          GenServer.server(),
          iodata | IO.chardata() | String.Chars.t()
        ) :: :ok | error
  def write(structured_io, data) do
    request = {:deprecated_write, data}
    GenServer.cast(structured_io, request)
  end

  # Callbacks

  @impl true

  def handle_call(:mode, _from, %{mode: mode} = state), do: {:reply, mode, state}

  def handle_call(
        {
          :read,
          count = count_or_match
        },
        _from,
        state
      )
      when is_integer(count_or_match) do
    unit = scan_unit(state)
    scan(state, :scan, [unit, count])
  end

  def handle_call(
        {
          :read,
          match = count_or_match
        },
        _from,
        state
      )
      when is_binary(count_or_match) do
    case binary_data(state) do
      {:error, _} = error ->
        {:reply, error, state}

      {:ok, binary} ->
        unit = scan_unit(state)
        count = measure(match, state)

        binary
        |> Scanner.scan(unit, count)
        |> case do
          {^match, _} = result -> result
          _ -> nil
        end
        |> read_reply(state)
    end
  end

  def handle_call({:read_across, left, right}, _from, state) do
    scan(state, :scan_across, [left, right])
  end

  def handle_call({:read_across_ignoring_overlap, left, right}, _from, state) do
    scan(state, :scan_across_ignoring_overlap, [left, right])
  end

  def handle_call({:read_between, left, right}, _from, state) do
    scan(state, :scan_between, [left, right])
  end

  def handle_call(
        {:read_between_ignoring_overlap, left, right},
        _from,
        state
      ) do
    scan(state, :scan_between_ignoring_overlap, [left, right])
  end

  def handle_call({:read_through, right}, _from, state) do
    scan(state, :scan_through, [right])
  end

  def handle_call({:read_to, right}, _from, state) do
    scan(state, :scan_to, [right])
  end

  defdelegate handle_call(request, from, state), to: Deprecated

  # # TODO: Add a handler for the :write message when the :deprecated_write message is eliminated
  # def handle_cast({:write, new_data}, %{data: data}=state) do
  #   new_state = %{state | data: [data, new_data]}

  #   {:noreply, new_state}
  # end

  defdelegate handle_cast(request, state), to: Deprecated

  @doc false
  @impl true
  def init(args), do: {:ok, args}

  @spec binary_data(State.t()) :: {:ok, binary} | error

  # # TODO: Don’t handle `nil` :mode when deprecated `.start*` usage is eliminated
  defp binary_data(%{data: iodata, mode: nil}) do
    {:ok, IO.iodata_to_binary(iodata)}
  end

  defp binary_data(%{data: iodata, mode: :binary}) do
    {:ok, IO.iodata_to_binary(iodata)}
  end

  defp binary_data(%{data: chardata, mode: :unicode}) do
    try do
      IO.chardata_to_string(chardata)
    rescue
      e in UnicodeConversionError -> {:error, e}
    else
      string ->
        {:ok, string}
    end
  end

  @spec compute_mode(mode, atom) :: {:ok, mode} | error

  defp compute_mode(mode, _) when mode in @valid_modes, do: {:ok, mode}

  defp compute_mode(mode, _), do: {:error, "invalid mode #{inspect(mode)}"}

  @spec maybe_standardize_error(any) :: error | any

  defp maybe_standardize_error({:error, error}) do
    if Exception.exception?(error) do
      type =
        error
        |> Map.fetch!(:__struct__)
        |> inspect

      {:error, "#{type}: #{error.message}"}
    else
      if is_atom(error) do
        {:error, error}
      else
        {:error, to_string(error)}
      end
    end
  end

  defp maybe_standardize_error(other), do: other

  @spec measure(binary, State.t()) :: non_neg_integer

  defp measure(binary, %{mode: :binary}), do: byte_size(binary)

  defp measure(binary, %{mode: :unicode}), do: String.length(binary)

  @spec read_reply(
          nil | {Scanner.match(), Scanner.remainder()},
          State.t()
        ) :: {:reply, Scanner.match(), State.t()}

  defp read_reply(nil, state), do: {:reply, "", state}

  defp read_reply({match, remainder}, state) do
    new_state = %{state | data: remainder}

    {:reply, match, new_state}
  end

  @spec scan(
          State.t(),
          atom,
          [any]
        ) :: {:reply, Scanner.match() | error, State.t()}
  defp scan(state, function, arguments) do
    case binary_data(state) do
      {:error, _} = error ->
        {:reply, error, state}

      {:ok, binary} ->
        Scanner
        |> apply(function, [binary | arguments])
        |> read_reply(state)
    end
  end

  @spec scan_unit(State.t()) :: Scanner.unit()

  defp scan_unit(%{mode: :binary} = _state), do: :bytes

  defp scan_unit(%{mode: :unicode} = _state), do: :graphemes
end
