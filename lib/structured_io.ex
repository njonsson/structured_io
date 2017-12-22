defmodule StructuredIO do
  @moduledoc """
  A process for performing I/O of structured data, such as markup or
  binary-encoded data.
  """


  defmodule State do
    @moduledoc false

    defstruct data: [], mode: nil

    @typedoc false
    @type t :: %__MODULE__{data: iodata, mode: nil | :binary | :unicode}
  end


  use GenServer

  require Logger

  alias StructuredIO.Scanner


  @typedoc """
  An error result.
  """
  @type error :: {:error, atom | binary}


  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `from` and ending with the specified `through`, using the specified `timeout`
  (defaults to 5,000 milliseconds). The operation is Unicode-unsafe.

  If the data read does not begin with `from`, the result is an empty binary
  (`""`). Likewise, if `through` is not encountered, the result is an empty
  binary (`""`).

  ## Examples

      iex> {:ok, structured_io} = StructuredIO.start_link
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<0, 0, 0, 1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.binread_across structured_io,
      ...>                             <<0, 0, 0>>,
      ...>                             <<255, 255, 255>>
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.binread_across structured_io,
      ...>                             <<0, 0, 0>>,
      ...>                             <<255, 255, 255>>
      <<0, 0, 0, 1, 2, 3, 255, 255, 255>>
      iex> StructuredIO.binread_across structured_io,
      ...>                             <<0, 0, 0>>,
      ...>                             <<255, 255, 255>>
      <<0, 0, 0, 4, 5, 6, 255, 255, 255>>
      iex> StructuredIO.binread_across structured_io,
      ...>                             <<0, 0, 0>>,
      ...>                             <<255, 255, 255>>
      ""
  """
  @spec binread_across(GenServer.server, binary, binary) :: Scanner.match
  @spec binread_across(GenServer.server,
                       binary,
                       binary,
                       timeout) :: Scanner.match
  def binread_across(structured_io, from, through, timeout \\ 5000) do
    request = {:binread_across, from, through}
    GenServer.call structured_io, request, timeout
  end


  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `through` is encountered, using the specified `timeout` (defaults to 5,000
  milliseconds). The operation is Unicode-unsafe.

  If `through` is not encountered, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok, structured_io} = StructuredIO.start_link
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.binread_through structured_io,
      ...>                              <<255, 255, 255>>
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<255, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.binread_through structured_io,
      ...>                              <<255, 255, 255>>
      <<1, 2, 3, 255, 255, 255>>
      iex> StructuredIO.binread_through structured_io,
      ...>                              <<255, 255, 255>>
      <<4, 5, 6, 255, 255, 255>>
      iex> StructuredIO.binread_through structured_io,
      ...>                              <<255, 255, 255>>
      ""
  """
  @spec binread_through(GenServer.server, binary) :: Scanner.match
  @spec binread_through(GenServer.server, binary, timeout) :: Scanner.match
  def binread_through(structured_io, through, timeout \\ 5000) do
    request = {:binread_through, through}
    GenServer.call structured_io, request, timeout
  end


  @doc """
  Asynchronously writes the specified `iodata` as a binary to the specified
  `structured_io`.  The operation is Unicode-unsafe.

  See `#{inspect __MODULE__}.binread_across/3` and
  `#{inspect __MODULE__}.binread_through/2` for examples.
  """
  @spec binwrite(GenServer.server, iodata) :: :ok | error
  def binwrite(structured_io, iodata) do
    request = {:binwrite, iodata}
    GenServer.call structured_io, request
  end


  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `from` and ending with the specified `through`, using the specified `timeout`
  (defaults to 5,000 milliseconds).

  If the data read does not begin with `from`, the result is an empty binary
  (`""`). Likewise, if `through` is not encountered, the result is an empty
  binary (`""`).

  ## Examples

      iex> {:ok, structured_io} = StructuredIO.start_link
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
  """
  @spec read_across(GenServer.server, binary, binary) :: binary
  @spec read_across(GenServer.server, binary, binary, timeout) :: binary
  def read_across(structured_io, from, through, timeout \\ 5000) do
    request = {:read_across, from, through}
    GenServer.call structured_io, request, timeout
  end


  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `through` is encountered, using the specified `timeout` (defaults to 5,000
  milliseconds).

  If `through` is not encountered, the result is an empty binary (`""`).

  ## Examples

      iex> {:ok, structured_io} = StructuredIO.start_link
      iex> StructuredIO.write structured_io,
      ...>                    "foo<br /"
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br />"
      ""
      iex> StructuredIO.write structured_io,
      ...>                    ">bar<br />"
      :ok
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br />"
      "foo<br />"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br />"
      "bar<br />"
      iex> StructuredIO.read_through structured_io,
      ...>                           "<br />"
      ""
  """
  @spec read_through(GenServer.server, binary) :: binary
  @spec read_through(GenServer.server, binary, timeout) :: binary
  def read_through(structured_io, through, timeout \\ 5000) do
    request = {:read_through, through}
    GenServer.call structured_io, request, timeout
  end


  @doc """
  Starts a `#{inspect __MODULE__}` process without links (outside a
  supervision tree) with the specified `options`.

  See `#{inspect __MODULE__}.start_link/2`.
  """
  @spec start :: GenServer.on_start
  @spec start(GenServer.options) :: GenServer.on_start
  def start(options \\ []), do: GenServer.start(__MODULE__, %State{}, options)


  @doc """
  Starts a `#{inspect __MODULE__}` process linked to the current process with
  the specified `options`.

  See `#{inspect __MODULE__}.binread_across/3`,
  `#{inspect __MODULE__}.binread_through/2`,
  `#{inspect __MODULE__}.read_across/3`, and
  `#{inspect __MODULE__}.read_through/2` for examples.
  """
  @spec start_link :: GenServer.on_start
  @spec start_link(GenServer.options) :: GenServer.on_start
  def start_link(options \\ []) do
    GenServer.start_link __MODULE__, %State{}, options
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
  Asynchronously writes the specified `chardata` as a binary to the specified
  `structured_io`.

  See `#{inspect __MODULE__}.read_across/3` and
  `#{inspect __MODULE__}.read_through/2` for examples.
  """
  @spec write(GenServer.server, IO.chardata | String.Chars.t) :: :ok | error
  def write(structured_io, chardata) do
    request = {:write, chardata}
    GenServer.call structured_io, request
  end


  # Callbacks


  def handle_call({:binread_across, _, _}, _from, %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "read_across/3")

    {:reply, reply, state}
  end

  def handle_call({:binread_across, binread_from, binread_through},
                  _from,
                  %{data: iodata}=state) do
    iodata
    |> IO.iodata_to_binary
    |> Scanner.scan_across(binread_from, binread_through)
    |> read_reply(state)
  end


  def handle_call({:binread_through, _}, _from, %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "read_through/2")

    {:reply, reply, state}
  end

  def handle_call({:binread_through, binread_through},
                  _from,
                  %{data: iodata}=state) do
    iodata
    |> IO.iodata_to_binary
    |> Scanner.scan_through(binread_through)
    |> read_reply(state)
  end


  def handle_call({:binwrite, _}, _from, %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "write/2")

    {:reply, reply, state}
  end

  def handle_call({:binwrite, _}=request, _from, state) do
    GenServer.cast self(), request

    new_state = if is_nil(state.mode) do
                  Logger.debug fn ->
                    build_log_message "Using binary mode"
                  end
                  %{state | mode: :binary}
                else
                  state
                end

    {:reply, :ok, new_state}
  end


  def handle_call({:read_across, _, _}, _from, %{mode: :binary}=state) do
    reply = mode_error("binary", "binread_across/3")

    {:reply, reply, state}
  end

  def handle_call({:read_across, read_from, read_through},
                  _from,
                  %{data: chardata}=state) do
    chardata
    |> IO.chardata_to_string
    |> Scanner.scan_across(read_from, read_through)
    |> read_reply(state)
  end


  def handle_call({:read_through, _}, _from, %{mode: :binary}=state) do
    reply = mode_error("binary", "binread_through/2")

    {:reply, reply, state}
  end

  def handle_call({:read_through, read_through},
                  _from,
                  %{data: chardata}=state) do
    chardata
    |> IO.chardata_to_string
    |> Scanner.scan_through(read_through)
    |> read_reply(state)
  end


  def handle_call({:write, _}, _from, %{mode: :binary}=state) do
    reply = mode_error("binary", "binwrite/2")

    {:reply, reply, state}
  end

  def handle_call({:write, _}=request, _from, state) do
    GenServer.cast self(), request

    new_state = if is_nil(state.mode) do
                  Logger.debug fn ->
                    build_log_message "Using Unicode mode"
                  end
                  %{state | mode: :unicode}
                else
                  state
                end

    {:reply, :ok, new_state}
  end


  def handle_cast({:binwrite, iodata}, %{data: data, mode: :binary}=state) do
    new_state = %{state | data: [data, iodata]}

    {:noreply, new_state}
  end


  def handle_cast({:write, chardata}, %{data: data, mode: :unicode}=state) do
    new_state = %{state | data: [data, chardata]}

    {:noreply, new_state}
  end


  @spec build_log_message(binary) :: binary
  defp build_log_message(message) do
    "#{message} in #{inspect __MODULE__} #{inspect self()}"
  end


  @spec mode_error(binary, binary) :: error
  defp mode_error(mode_name, correct_fun_name) do
    {:error,
     "In #{mode_name} mode -- call #{inspect __MODULE__}.#{correct_fun_name} instead"}
  end


  @spec read_reply(nil | {Scanner.match, Scanner.remaining},
                   State.t) :: {:reply, Scanner.match, State.t}

  defp read_reply(nil, state), do: {:reply, "", state}

  defp read_reply({match, remaining}, state) do
    new_state = %{state | data: remaining}

    {:reply, match, new_state}
  end
end
