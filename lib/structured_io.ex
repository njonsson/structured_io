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

    defstruct data: [], mode: nil

    @typedoc false
    @type t :: %__MODULE__{data: iodata | IO.chardata | String.Chars.t,
                           mode: StructuredIO.mode}
  end


  use GenServer

  alias StructuredIO.{Deprecated,Scanner}


  @typedoc """
  An error result.
  """
  @type error :: {:error, atom | binary}


  @typedoc """
  A mode of operation for the process: either binary or Unicode.

  See `#{inspect __MODULE__}.start/2` and `#{inspect __MODULE__}.start_link/2`.
  """
  @type mode :: :binary | :unicode

  @valid_modes [:binary, :unicode]


  @doc false
  defdelegate binread_across(structured_io,
                             from,
                             through,
                             timeout \\ 5000), to: Deprecated


  @doc false
  defdelegate binread_between(structured_io,
                              after_data,
                              before_data,
                              timeout \\ 5000), to: Deprecated


  @doc false
  defdelegate binread_through(structured_io,
                              through,
                              timeout \\ 5000), to: Deprecated


  @doc false
  defdelegate binread_to(structured_io, to, timeout \\ 5000), to: Deprecated


  @doc false
  defdelegate binwrite(structured_io, iodata), to: Deprecated


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
  @spec mode(GenServer.server) :: mode
  def mode(structured_io) do
    request = :mode
    GenServer.call structured_io, request
  end


  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `from` and ending with the specified `through`, inclusive, using the specified
  `timeout` (defaults to 5,000 milliseconds).

  If the data read does not begin with `from`, the result is an empty binary
  (`""`). Likewise, if `through` is not encountered, the result is an empty
  binary.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<0, 0, 0, 1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      <<0, 0, 0, 1, 2, 3, 255, 255, 255>>
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      <<0, 0, 0, 4, 5, 6, 255, 255, 255>>
      iex> StructuredIO.read_across structured_io,
      ...>                          <<0, 0, 0>>,
      ...>                          <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo</elem"
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    "><elem>bar</elem>"
      :ok
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      "<elem>foo</elem>"
      iex> StructuredIO.read_across structured_io,
      ...>                          "<elem>",
      ...>                          "</elem>"
      "<elem>bar</elem>"
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
  @spec read_across(GenServer.server, binary, binary) :: binary | error
  @spec read_across(GenServer.server, binary, binary, timeout) :: binary | error
  def read_across(structured_io, from, through, timeout \\ 5000) do
    request = {:read_across, from, through}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `after_data` and ending with the specified `before_data`, exclusive, using the
  specified `timeout` (defaults to 5,000 milliseconds).

  If the data read does not begin with `after_data`, the result is an empty
  binary (`""`). Likewise, if `before_data` is not encountered, the result is an
  empty binary.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:binary)
      iex> StructuredIO.write structured_io,
      ...>                    <<0, 0, 0, 1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           <<0, 0, 0>>,
      ...>                           <<255, 255, 255>>
      ""
      iex> StructuredIO.write structured_io,
      ...>                    <<255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           <<0, 0, 0>>,
      ...>                           <<255, 255, 255>>
      <<1, 2, 3>>
      iex> StructuredIO.read_between structured_io,
      ...>                           <<0, 0, 0>>,
      ...>                           <<255, 255, 255>>
      <<4, 5, 6>>
      iex> StructuredIO.read_between structured_io,
      ...>                           <<0, 0, 0>>,
      ...>                           <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> StructuredIO.write structured_io,
      ...>                    "<elem>foo</elem"
      :ok
      iex> StructuredIO.read_between structured_io,
      ...>                           "<elem>",
      ...>                           "</elem>"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    "><elem>bar</elem>"
      :ok
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
  @spec read_between(GenServer.server, binary, binary) :: binary | error
  @spec read_between(GenServer.server,
                     binary,
                     binary,
                     timeout) :: binary | error
  def read_between(structured_io, after_data, before_data, timeout \\ 5000) do
    request = {:read_between, after_data, before_data}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `through` is encountered, including `through`, using the specified `timeout`
  (defaults to 5,000 milliseconds).

  If `through` is not encountered, the result is an empty binary (`""`).

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
  @spec read_through(GenServer.server, binary) :: binary | error
  @spec read_through(GenServer.server, binary, timeout) :: binary | error
  def read_through(structured_io, through, timeout \\ 5000) do
    request = {:read_through, through}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc """
  Reads data from the specified `structured_io` if and until the specified `to`
  is encountered, excluding `to`, using the specified `timeout` (defaults to
  5,000 milliseconds).

  If `to` is not encountered, the result is an empty binary (`""`).

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
  @spec read_to(GenServer.server, binary) :: binary | error
  @spec read_to(GenServer.server, binary, timeout) :: binary | error
  def read_to(structured_io, to, timeout \\ 5000) do
    request = {:read_to, to}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc false
  defdelegate start, to: Deprecated


  @doc """
  Starts a `#{inspect __MODULE__}` process without links (outside a
  supervision tree) with the specified `mode` and `options`.

  ## Examples

      iex> StructuredIO.start :super_pursuit_mode
      {:error,
       "invalid mode :super_pursuit_mode"}

  See `#{inspect __MODULE__}.start_link/2`.
  """
  @spec start(mode) :: GenServer.on_start
  @spec start(mode, GenServer.options) :: GenServer.on_start
  def start(mode, options \\ []) do
    with {:ok, mode} <- compute_mode(mode, :start) do
      GenServer.start __MODULE__, %State{mode: mode}, options
    end
  end


  @doc false
  defdelegate start_link, to: Deprecated


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
  @spec start_link(mode) :: GenServer.on_start
  @spec start_link(mode, GenServer.options) :: GenServer.on_start
  def start_link(mode, options \\ []) do
    with {:ok, mode} <- compute_mode(mode, :start_link) do
      GenServer.start_link __MODULE__, %State{mode: mode}, options
    end
  end


  @doc """
  Synchronously stops the specified `structured_io` process with the specified
  `reason` (defaults to `:normal`) and `timeout` (defaults to infinity).
  """
  @spec stop(GenServer.server) :: :ok
  @spec stop(GenServer.server, term) :: :ok
  @spec stop(GenServer.server, term, timeout) :: :ok
  def stop(structured_io, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop structured_io, reason, timeout
  end


  @doc """
  Asynchronously writes the specified `data` as a binary to the specified
  `structured_io`.

  See `#{inspect __MODULE__}.read_across/3`,
  `#{inspect __MODULE__}.read_between/3`,
  `#{inspect __MODULE__}.read_through/2`, and `#{inspect __MODULE__}.read_to/2`
  for examples.
  """
  @spec write(GenServer.server,
              iodata | IO.chardata | String.Chars.t) :: :ok | error
  def write(structured_io, data) do
    request = {:deprecated_write, data}
    GenServer.cast structured_io, request
  end


  # Callbacks


  def handle_call(:mode, _from, %{mode: mode}=state), do: {:reply, mode, state}


  def handle_call({:read_across, after_data, before_data}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_across(after_data, before_data)
        |> read_reply(state)
    end
  end


  def handle_call({:read_between, after_data, before_data}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_between(after_data, before_data)
        |> read_reply(state)
    end
  end


  def handle_call({:read_through, read_through}, _from, state) do
    case binary_data(state) do
      {:error, _}=error ->
        {:reply, error, state}
      {:ok, binary} ->
        binary
        |> Scanner.scan_through(read_through)
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


  @doc false
  defdelegate handle_call(request, from, state), to: Deprecated


  # # TODO: Add a handler for the :write message when the :deprecated_write message is eliminated
  # def handle_cast({:write, new_data}, %{data: data}=state) do
  #   new_state = %{state | data: [data, new_data]}

  #   {:noreply, new_state}
  # end

  @doc false
  defdelegate handle_cast(request, state), to: Deprecated


  def init(args), do: {:ok, args}


  @spec binary_data(State.t) :: {:ok, binary} | error

  # # TODO: Don’t handle `nil` :mode when deprecated `.start*` usage is eliminated
  defp binary_data(%{data: iodata, mode: nil}) do
    {:ok, IO.iodata_to_binary(iodata)}
  end

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
                   State.t) :: {:reply, binary, State.t}

  defp read_reply(nil, state), do: {:reply, "", state}

  defp read_reply({match, remainder}, state) do
    new_state = %{state | data: remainder}

    {:reply, match, new_state}
  end
end
