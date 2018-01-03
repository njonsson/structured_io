defmodule StructuredIO.Deprecated do
  @moduledoc """
  Provides deprecated functions to `StructuredIO`.

  ## Encoding

  Mixing the use of binary mode and Unicode mode results in a
  `t:StructuredIO.error/0`.
  """


  require Logger

  alias StructuredIO.{Scanner,State}


  @valid_modes [:binary, :unicode]


  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `from` and ending with the specified `through`, inclusive, using the specified
  `timeout` (defaults to 5,000 milliseconds).

  If the data read does not begin with `from`, the result is an empty binary
  (`""`). Likewise, if `through` is not encountered, the result is an empty
  binary.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link
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

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link
      iex> StructuredIO.binwrite structured_io,
      ...>                       "<elem>"
      :ok
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment1
      :ok
      iex> StructuredIO.binread_across structured_io,
      ...>                             "<elem>",
      ...>                             "</elem>"
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment2
      :ok
      iex> StructuredIO.binwrite structured_io,
      ...>                       "</elem>"
      :ok
      iex> StructuredIO.binread_across structured_io,
      ...>                             "<elem>",
      ...>                             "</elem>"
      "<elem>😕</elem>"
      iex> StructuredIO.binread_across structured_io,
      ...>                             "<elem>",
      ...>                             "</elem>"
      ""
  """
  @spec binread_across(GenServer.server,
                       binary,
                       binary) :: binary | StructuredIO.error
  @spec binread_across(GenServer.server,
                       binary,
                       binary,
                       timeout) :: binary | StructuredIO.error
  def binread_across(structured_io, from, through, timeout \\ 5000) do
    log_warning_about_bin_function :binread_across, :read_across
    request = {:deprecated_binread_across, from, through}
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
      ...>  structured_io} = StructuredIO.start_link
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<0, 0, 0, 1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.binread_between structured_io,
      ...>                              <<0, 0, 0>>,
      ...>                              <<255, 255, 255>>
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<255, 0, 0, 0, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.binread_between structured_io,
      ...>                              <<0, 0, 0>>,
      ...>                              <<255, 255, 255>>
      <<1, 2, 3>>
      iex> StructuredIO.binread_between structured_io,
      ...>                              <<0, 0, 0>>,
      ...>                              <<255, 255, 255>>
      <<4, 5, 6>>
      iex> StructuredIO.binread_between structured_io,
      ...>                              <<0, 0, 0>>,
      ...>                              <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link
      iex> StructuredIO.binwrite structured_io,
      ...>                       "<elem>"
      :ok
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment1
      :ok
      iex> StructuredIO.binread_between structured_io,
      ...>                              "<elem>",
      ...>                              "</elem>"
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment2
      :ok
      iex> StructuredIO.binwrite structured_io,
      ...>                       "</elem>"
      :ok
      iex> StructuredIO.binread_between structured_io,
      ...>                              "<elem>",
      ...>                              "</elem>"
      "😕"
      iex> StructuredIO.binread_between structured_io,
      ...>                              "<elem>",
      ...>                              "</elem>"
      ""
  """
  @spec binread_between(GenServer.server,
                        binary,
                        binary) :: binary | StructuredIO.error
  @spec binread_between(GenServer.server,
                        binary,
                        binary,
                        timeout) :: binary | StructuredIO.error
  def binread_between(structured_io,
                      after_data,
                      before_data,
                      timeout \\ 5000) do
    log_warning_about_bin_function :binread_between, :read_between
    request = {:deprecated_binread_between, after_data, before_data}
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
      ...>  structured_io} = StructuredIO.start_link
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

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment1
      :ok
      iex> StructuredIO.binread_through structured_io,
      ...>                              "<br/>"
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment2
      :ok
      iex> StructuredIO.binwrite structured_io,
      ...>                       "<br/>"
      :ok
      iex> StructuredIO.binread_through structured_io,
      ...>                              "<br/>"
      "😕<br/>"
      iex> StructuredIO.binread_through structured_io,
      ...>                              "<br/>"
      ""
  """
  @spec binread_through(GenServer.server, binary) :: binary | StructuredIO.error
  @spec binread_through(GenServer.server,
                        binary,
                        timeout) :: binary | StructuredIO.error
  def binread_through(structured_io, through, timeout \\ 5000) do
    log_warning_about_bin_function :binread_through, :read_through
    request = {:deprecated_binread_through, through}
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
      ...>  structured_io} = StructuredIO.start_link
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<1, 2, 3, 255, 255>>
      :ok
      iex> StructuredIO.binread_to structured_io,
      ...>                         <<255, 255, 255>>
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       <<255, 4, 5, 6, 255, 255, 255>>
      :ok
      iex> StructuredIO.binread_to structured_io,
      ...>                         <<255, 255, 255>>
      <<1, 2, 3>>
      iex> StructuredIO.binread_through structured_io,
      ...>                              <<255, 255, 255>>
      <<255, 255, 255>>
      iex> StructuredIO.binread_to structured_io,
      ...>                         <<255, 255, 255>>
      <<4, 5, 6>>
      iex> StructuredIO.binread_to structured_io,
      ...>                         <<255, 255, 255>>
      ""

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link
      iex> <<fragment1::binary-size(3), fragment2::binary>> = "😕"
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment1
      :ok
      iex> StructuredIO.binread_to structured_io,
      ...>                         "<br/>"
      ""
      iex> StructuredIO.binwrite structured_io,
      ...>                       fragment2
      :ok
      iex> StructuredIO.binwrite structured_io,
      ...>                       "<br/>"
      :ok
      iex> StructuredIO.binread_to structured_io,
      ...>                         "<br/>"
      "😕"
      iex> StructuredIO.binread_to structured_io,
      ...>                         "<br/>"
      ""
  """
  @spec binread_to(GenServer.server, binary) :: binary | StructuredIO.error
  @spec binread_to(GenServer.server,
                   binary,
                   timeout) :: binary | StructuredIO.error
  def binread_to(structured_io, to, timeout \\ 5000) do
    log_warning_about_bin_function :binread_to, :read_to
    request = {:deprecated_binread_to, to}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc """
  Asynchronously writes the specified `iodata` as a binary to the specified
  `structured_io`.

  See `#{inspect __MODULE__}.binread_across/3`,
  `#{inspect __MODULE__}.binread_between/3`,
  `#{inspect __MODULE__}.binread_through/2`, and
  `#{inspect __MODULE__}.binread_to/2` for examples.
  """
  @spec binwrite(GenServer.server, iodata) :: :ok | StructuredIO.error
  def binwrite(structured_io, iodata) do
    log_warning_about_bin_function :binwrite, :write
    request = {:deprecated_binwrite, iodata}
    structured_io
    |> GenServer.call(request)
    |> convert_if_error
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
      ...>  structured_io} = StructuredIO.start_link
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
      ...>  structured_io} = StructuredIO.start_link
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
  @spec read_across(GenServer.server,
                    binary,
                    binary) :: binary | StructuredIO.error
  @spec read_across(GenServer.server,
                    binary,
                    binary,
                    timeout) :: binary | StructuredIO.error
  def read_across(structured_io, from, through, timeout \\ 5000) do
    request = {:deprecated_read_across, from, through}
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
      ...>  structured_io} = StructuredIO.start_link
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
      ...>  structured_io} = StructuredIO.start_link
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
  @spec read_between(GenServer.server,
                     binary,
                     binary) :: binary | StructuredIO.error
  @spec read_between(GenServer.server,
                     binary,
                     binary,
                     timeout) :: binary | StructuredIO.error
  def read_between(structured_io, after_data, before_data, timeout \\ 5000) do
    request = {:deprecated_read_between, after_data, before_data}
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
      ...>  structured_io} = StructuredIO.start_link
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
      ...>  structured_io} = StructuredIO.start_link
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
  @spec read_through(GenServer.server, binary) :: binary | StructuredIO.error
  @spec read_through(GenServer.server,
                     binary,
                     timeout) :: binary | StructuredIO.error
  def read_through(structured_io, through, timeout \\ 5000) do
    request = {:deprecated_read_through, through}
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
      ...>  structured_io} = StructuredIO.start_link
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
      ...>  structured_io} = StructuredIO.start_link
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
  @spec read_to(GenServer.server, binary) :: binary | StructuredIO.error
  @spec read_to(GenServer.server,
                binary,
                timeout) :: binary | StructuredIO.error
  def read_to(structured_io, to, timeout \\ 5000) do
    request = {:deprecated_read_to, to}
    structured_io
    |> GenServer.call(request, timeout)
    |> convert_if_error
  end


  @doc """
  Starts a `#{inspect StructuredIO}` process without links (outside a
  supervision tree).

  See `#{inspect __MODULE__}.start_link/0`.
  """
  @spec start :: GenServer.on_start
  def start do
    with {:ok, mode} <- compute_mode(:start) do
      GenServer.start StructuredIO, %State{mode: mode}, []
    end
  end


  @doc """
  Starts a `#{inspect StructuredIO}` process linked to the current process.

  See `#{inspect __MODULE__}.binread_across/3`,
  `#{inspect __MODULE__}.binread_between/3`,
  `#{inspect __MODULE__}.binread_through/2`,
  `#{inspect __MODULE__}.binread_to/2`, `#{inspect __MODULE__}.read_across/3`,
  `#{inspect __MODULE__}.read_between/3`,
  `#{inspect __MODULE__}.read_through/2`, and `#{inspect __MODULE__}.read_to/2`
  for examples.
  """
  @spec start_link :: GenServer.on_start
  def start_link do
    with {:ok, mode} <- compute_mode(:start_link) do
      GenServer.start StructuredIO, %State{mode: mode}, []
    end
  end


  # Callbacks


  @doc false
  def handle_call({:deprecated_binread_across, _, _},
                  _from,
                  %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "read_across/3")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_binread_across, binread_from, binread_through},
                  _from,
                  %{data: iodata}=state) do
    iodata
    |> IO.iodata_to_binary
    |> Scanner.scan_across(binread_from, binread_through)
    |> read_reply(state)
  end


  @doc false
  def handle_call({:deprecated_binread_between, _, _},
                  _from,
                  %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "read_between/3")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_binread_between, after_data, before_data},
                  _from,
                  %{data: iodata}=state) do
    iodata
    |> IO.iodata_to_binary
    |> Scanner.scan_between(after_data, before_data)
    |> read_reply(state)
  end


  @doc false
  def handle_call({:deprecated_binread_through, _},
                  _from,
                  %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "read_through/2")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_binread_through, binread_through},
                  _from,
                  %{data: iodata}=state) do
    iodata
    |> IO.iodata_to_binary
    |> Scanner.scan_through(binread_through)
    |> read_reply(state)
  end


  @doc false
  def handle_call({:deprecated_binread_to, _},
                  _from,
                  %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "read_to/2")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_binread_to, binread_to},
                  _from,
                  %{data: iodata}=state) do
    iodata
    |> IO.iodata_to_binary
    |> Scanner.scan_to(binread_to)
    |> read_reply(state)
  end


  @doc false
  def handle_call({:deprecated_binwrite, _}, _from, %{mode: :unicode}=state) do
    reply = mode_error("Unicode", "write/2")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_binwrite, _}=request, _from, state) do
    GenServer.cast self(), request

    {:reply, :ok, state}
  end


  @doc false
  def handle_call({:deprecated_read_across, _, _},
                  _from,
                  %{mode: :binary}=state) do
    reply = mode_error("binary", "binread_across/3")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_read_across, read_from, read_through},
                  _from,
                  %{data: chardata}=state) do
    try do
      IO.chardata_to_string chardata
    rescue
      e in UnicodeConversionError -> {:reply, {:error, e}, state}
    else
      string ->
        string
        |> Scanner.scan_across(read_from, read_through)
        |> read_reply(state)
    end
  end


  @doc false
  def handle_call({:deprecated_read_between, _, _},
                  _from,
                  %{mode: :binary}=state) do
    reply = mode_error("binary", "binread_between/3")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_read_between, after_data, before_data},
                  _from,
                  %{data: chardata}=state) do
    try do
      IO.chardata_to_string chardata
    rescue
      e in UnicodeConversionError -> {:reply, {:error, e}, state}
    else
      string ->
        string
        |> Scanner.scan_between(after_data, before_data)
        |> read_reply(state)
    end
  end


  @doc false
  def handle_call({:deprecated_read_through, _},
                  _from,
                  %{mode: :binary}=state) do
    reply = mode_error("binary", "binread_through/2")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_read_through, read_through},
                  _from,
                  %{data: chardata}=state) do
    try do
      IO.chardata_to_string chardata
    rescue
      e in UnicodeConversionError -> {:reply, {:error, e}, state}
    else
      string ->
        string
        |> Scanner.scan_through(read_through)
        |> read_reply(state)
    end
  end


  @doc false
  def handle_call({:deprecated_read_to, _}, _from, %{mode: :binary}=state) do
    reply = mode_error("binary", "binread_to/2")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_read_to, read_to},
                  _from,
                  %{data: chardata}=state) do
    try do
      IO.chardata_to_string chardata
    rescue
      e in UnicodeConversionError -> {:reply, {:error, e}, state}
    else
      string ->
        string
        |> Scanner.scan_to(read_to)
        |> read_reply(state)
    end
  end


  @doc false
  def handle_call({:deprecated_write, _}, _from, %{mode: :binary}=state) do
    reply = mode_error("binary", "binwrite/2")

    {:reply, reply, state}
  end

  @doc false
  def handle_call({:deprecated_write, _}=request, _from, state) do
    GenServer.cast self(), request

    {:reply, :ok, state}
  end


  @doc false
  def handle_cast({:deprecated_binwrite, iodata},
                  %{data: data}=state) do
    new_data = [data, iodata]
    new_mode = Map.get(state, :mode) || :binary
    new_state = %{state | data: new_data, mode: new_mode}

    {:noreply, new_state}
  end


  @doc false
  def handle_cast({:deprecated_write, chardata}, %{data: data}=state) do
    new_data = [data, chardata]
    new_mode = Map.get(state, :mode) || :unicode
    new_state = %{state | data: new_data, mode: new_mode}

    {:noreply, new_state}
  end


  @doc false
  def init(args), do: {:ok, args}


  @spec compute_mode(atom) :: {:ok, nil}

  defp compute_mode(start_fun) do
    Logger.warn "*** DEPRECATED: #{inspect StructuredIO}.#{start_fun} without mode -- specify one of #{inspect @valid_modes}"
    {:ok, nil}
  end


  @spec convert_if_error(any) :: StructuredIO.error | any

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


  @spec log_warning_about_bin_function(any, any) :: :ok
  defp log_warning_about_bin_function(deprecated, sanctioned) do
    Logger.warn "*** DEPRECATED: #{inspect StructuredIO}.#{deprecated} -- call .#{sanctioned} in binary mode instead"
  end


  @spec mode_error(binary, binary) :: StructuredIO.error
  defp mode_error(mode_name, correct_fun_name) do
    {:error,
     "In #{mode_name} mode -- call #{inspect StructuredIO}.#{correct_fun_name} instead"}
  end


  @spec read_reply(nil | {Scanner.match, Scanner.remainder},
                   State.t) :: {:reply, binary, State.t}

  defp read_reply(nil, state), do: {:reply, "", state}

  defp read_reply({match, remainder}, state) do
    new_state = %{state | data: remainder}

    {:reply, match, new_state}
  end
end