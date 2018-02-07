defmodule StructuredIO do
  @moduledoc """
  A process for performing I/O of structured data, such as markup or
  binary-encoded data.

  ## Encoding

  The process operates in either **binary mode** or **Unicode mode** (see
  `#{inspect __MODULE__}.start/2` and `#{inspect __MODULE__}.start_link/2`).
  When in binary mode, the result of a read operation is a binary, regardless of
  whether the data read is `String.valid?/1`. In Unicode mode, the result of a
  read operation is an `t:error/0` if the data read is not properly encoded
  Unicode data.
  """


  defmodule State do
    @moduledoc false

    @enforce_keys [:mode]
    defstruct data: [], mode: nil

    @typedoc false
    @type t :: %__MODULE__{data: iodata | IO.chardata | String.Chars.t,
                           mode: StructuredIO.mode}
  end


  use GenServer

  alias StructuredIO.{Collector,Enumerator,Scanner}


  @typedoc """
  An error result.
  """
  @type error :: {:error, atom | binary}


  @typedoc """
  A binary value which marks the beginning of an enclosed data element.

  See `#{inspect __MODULE__}.read_across/3` and
  `#{inspect __MODULE__}.read_between/3`.
  """
  @type left :: Scanner.left


  @typedoc """
  The portion of a binary value matched in a read operation.

  See `#{inspect __MODULE__}.read_across/3`,
  `#{inspect __MODULE__}.read_between/3`,
  `#{inspect __MODULE__}.read_through/2`, and `#{inspect __MODULE__}.read_to/2`.
  """
  @type match :: Scanner.match


  @typedoc """
  A mode of operation for the process: either binary or Unicode.

  See `#{inspect __MODULE__}.start/2` and `#{inspect __MODULE__}.start_link/2`.
  """
  @type mode :: :binary | :unicode

  @valid_modes [:binary, :unicode]


  @typedoc """
  A binary value which marks the end of an enclosed or terminated data element.

  See `#{inspect __MODULE__}.read_across/3`,
  `#{inspect __MODULE__}.read_between/3`,
  `#{inspect __MODULE__}.read_through/2`, and `#{inspect __MODULE__}.read_to/2`.
  """
  @type right :: Scanner.right


  @doc """
  Returns a value that can be passed to `Enum.into/2` or `Enum.into/3` for
  writing data to the specified `structured_io`.

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
  @since "0.6.0"
  @spec collect(GenServer.server) :: Collector.t
  def collect(structured_io) do
    {:ok, collector} = Collector.new(%{process: structured_io,
                                       function: :write})
    collector
  end


  @doc """
  Returns a value that can be passed to functions such as `Enum.map/2` for
  reading data elements from the specified `structured_io`, using the specified
  `#{inspect __MODULE__}` `function`, and the specified `left` and/or `right`.

  Note that enumeration is not a purely functional operation; it consumes data
  elements from the underlying `#{inspect __MODULE__}` process.

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
      ...> |> Enum.map(&String.upcase/1)
      ["FOO<BR/>",
       "BAR<BR/>",
       "BAZ<BR/>"]
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br />"
      ""
  """

  @since "0.6.0"
  @spec enumerate_with(GenServer.server,
                       :read_across                  |
                       :read_across_ignoring_overlap |
                       :read_between                 |
                       :read_between_ignoring_overlap,
                       left,
                       right) :: Enumerator.t
  def enumerate_with(structured_io,
                     function,
                     left,
                     right) when function in ~w{read_across
                                                read_across_ignoring_overlap
                                                read_between
                                                read_between_ignoring_overlap}a do
    {:ok, enumerator} = Enumerator.new(%{process: structured_io,
                                         function: function,
                                         additional_arguments: [left, right]})
    enumerator
  end

  @since "0.6.0"
  @spec enumerate_with(GenServer.server,
                       :read_through | :read_to,
                       right) :: Enumerator.t
  def enumerate_with(structured_io,
                     function,
                     right) when function in [:read_through, :read_to] do
    {:ok, enumerator} = Enumerator.new(%{process: structured_io,
                                         function: function,
                                         additional_arguments: [right]})
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
  @since "0.5.0"
  @spec mode(GenServer.server) :: mode
  def mode(structured_io) do
    request = :mode
    GenServer.call structured_io, request
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

  @since "0.1.0"
  @spec read_across(GenServer.server, left, right) :: match | error

  @since "0.2.0"
  @spec read_across(GenServer.server, left, right, timeout) :: match | error

  def read_across(structured_io, left, right, timeout \\ 5000) do
    request = {:read_across, left, right}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
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
  @since "0.7.0"
  @spec read_across_ignoring_overlap(GenServer.server,
                                     left,
                                     right) :: match | error

  @since "0.7.0"
  @spec read_across_ignoring_overlap(GenServer.server,
                                     left,
                                     right,
                                     timeout) :: match | error

  def read_across_ignoring_overlap(structured_io,
                                   left,
                                   right,
                                   timeout \\ 5000) do
    request = {:read_across_ignoring_overlap, left, right}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
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

  @since "0.4.0"
  @spec read_between(GenServer.server, left, right) :: match | error

  @since "0.2.0"
  @spec read_between(GenServer.server, left, right, timeout) :: match | error

  def read_between(structured_io, left, right, timeout \\ 5000) do
    request = {:read_between, left, right}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
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
  @since "0.7.0"
  @spec read_between_ignoring_overlap(GenServer.server,
                                      left,
                                      right) :: match | error

  @since "0.7.0"
  @spec read_between_ignoring_overlap(GenServer.server,
                                      left,
                                      right,
                                      timeout) :: match | error

  def read_between_ignoring_overlap(structured_io,
                                    left,
                                    right,
                                    timeout \\ 5000) do
    request = {:read_between_ignoring_overlap, left, right}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
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

  @since "0.2.0"
  @spec read_through(GenServer.server, right) :: match | error

  @since "0.2.0"
  @spec read_through(GenServer.server, right, timeout) :: match | error

  def read_through(structured_io, right, timeout \\ 5000) do
    request = {:read_through, right}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
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

  @since "0.2.0"
  @spec read_to(GenServer.server, right) :: match | error

  @since "0.2.0"
  @spec read_to(GenServer.server, right, timeout) :: match | error

  def read_to(structured_io, right, timeout \\ 5000) do
    request = {:read_to, right}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc """
  Starts a `#{inspect __MODULE__}` process without links (outside a supervision
  tree) with the specified `mode` and `options`.

  ## Examples

      iex> StructuredIO.start :super_pursuit_mode
      {:error,
       "invalid mode :super_pursuit_mode"}

  See `#{inspect __MODULE__}.start_link/2`.
  """

  @since "0.5.0"
  @spec start(mode) :: GenServer.on_start

  @since "0.5.0"
  @spec start(mode, GenServer.options) :: GenServer.on_start

  def start(mode, options \\ []) do
    with {:ok, mode} <- compute_mode(mode, :start) do
      GenServer.start __MODULE__, %State{mode: mode}, options
    end
  end


  @doc """
  Starts a `#{inspect __MODULE__}` process linked to the current process with
  the specified `mode` and `options`.

  ## Examples

      iex> StructuredIO.start_link :super_pursuit_mode
      {:error,
       "invalid mode :super_pursuit_mode"}

  See `#{inspect __MODULE__}.mode/1`, `#{inspect __MODULE__}.read_across/3`,
  `#{inspect __MODULE__}.read_between/3`,
  `#{inspect __MODULE__}.read_through/2`, and `#{inspect __MODULE__}.read_to/2`
  for more examples.
  """

  @since "0.5.0"
  @spec start_link(mode) :: GenServer.on_start

  @since "0.5.0"
  @spec start_link(mode, GenServer.options) :: GenServer.on_start

  def start_link(mode, options \\ []) do
    with {:ok, mode} <- compute_mode(mode, :start_link) do
      GenServer.start_link __MODULE__, %State{mode: mode}, options
    end
  end


  @doc """
  Stops the specified `structured_io` process.
  """

  @since "0.1.0"
  @spec stop(GenServer.server) :: :ok

  @since "0.1.0"
  @spec stop(GenServer.server, term) :: :ok

  @since "0.1.0"
  @spec stop(GenServer.server, term, timeout) :: :ok

  def stop(structured_io, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop structured_io, reason, timeout
  end


  @doc """
  Writes the specified `data` to the specified `structured_io`.

  No timeout is available because the operation is performed asynchronously.

  See `#{inspect __MODULE__}.read_across/3`,
  `#{inspect __MODULE__}.read_between/3`,
  `#{inspect __MODULE__}.read_through/2`, and `#{inspect __MODULE__}.read_to/2`
  for examples.
  """
  @since "0.1.0"
  @spec write(GenServer.server,
              iodata | IO.chardata | String.Chars.t) :: :ok | error
  def write(structured_io, data) do
    request = {:write, data}
    GenServer.cast structured_io, request
  end


  # Callbacks


  def handle_call(:mode, _from, %{mode: mode}=state), do: {:reply, mode, state}


  def handle_call({:read_across, left, right}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_across(left, right)
        |> read_reply(state)
    end
  end


  def handle_call({:read_across_ignoring_overlap, left, right}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_across_ignoring_overlap(left, right)
        |> read_reply(state)
    end
  end


  def handle_call({:read_between, left, right}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_between(left, right)
        |> read_reply(state)
    end
  end


  def handle_call({:read_between_ignoring_overlap, left, right},
                  _from,
                  state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_between_ignoring_overlap(left, right)
        |> read_reply(state)
    end
  end


  def handle_call({:read_through, right}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_through(right)
        |> read_reply(state)
    end
  end


  def handle_call({:read_to, read_to}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_to(read_to)
        |> read_reply(state)
    end
  end


  def handle_cast({:write, new_data}, %{data: data}=state) do
    new_state = %{state | data: [data, new_data]}

    {:noreply, new_state}
  end


  @doc false
  def init(args), do: {:ok, args}


  @spec binary_data(State.t) :: {:ok, binary} | error

  defp binary_data(%{data: iodata, mode: :binary}) do
    {:ok, IO.iodata_to_binary(iodata)}
  end

  defp binary_data(%{data: chardata, mode: :unicode}) do
    try do
      IO.chardata_to_string chardata
    rescue
      e in UnicodeConversionError -> {:error, e}
    else
      string ->
        {:ok, string}
    end
  end


  @spec compute_mode(mode, atom) :: {:ok, mode} | error

  defp compute_mode(mode, _) when mode in @valid_modes, do: {:ok, mode}

  defp compute_mode(mode, _), do: {:error, "invalid mode #{inspect mode}"}


  @spec convert_if_error(any) :: error | any

  defp convert_if_error({:error, error}) do
    if Exception.exception?(error) do
      type = error
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

  defp convert_if_error(other), do: other


  @spec read_reply(nil | {Scanner.match, Scanner.remainder},
                   State.t) :: {:reply, Scanner.match, State.t}

  defp read_reply(nil, state), do: {:reply, "", state}

  defp read_reply({match, remainder}, state) do
    new_state = %{state | data: remainder}

    {:reply, match, new_state}
  end
end
