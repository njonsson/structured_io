defmodule StructuredIO.Behaviour do
  @moduledoc """
  Defines a behavioral contract that is satisfied by `StructuredIO`.
  """

  alias StructuredIO.{Collector, Enumerator}

  @doc """
  Returns a value that can be passed to `Enum.into/2` or `Enum.into/3` for
  writing data to the specified `structured_io`.
  """
  @doc since: "0.6.0"
  @callback collect(structured_io :: GenServer.server()) :: Collector.t()

  @doc """
  Returns a value that can be passed to functions such as `Enum.map/2` for
  reading data elements from the specified `structured_io`, using the specified
  `StructuredIO` `function`, and the specified `left` and/or `right`/`operation`.
  """

  @doc since: "0.6.0"
  @callback enumerate_with(
              structured_io :: GenServer.server(),
              function ::
                :read_across
                | :read_across_ignoring_overlap
                | :read_between
                | :read_between_ignoring_overlap,
              left :: StructuredIO.left(),
              right :: StructuredIO.right()
            ) :: Enumerator.t()

  @doc since: "0.6.0"
  @callback enumerate_with(
              structured_io :: GenServer.server(),
              function :: :read_through | :read_to,
              right :: StructuredIO.right()
            ) :: Enumerator.t()

  @doc since: "1.3.0"
  @callback enumerate_with(
              structured_io :: GenServer.server(),
              function :: :read_complex,
              operation :: StructuredIO.operation()
            ) :: Enumerator.t()

  @doc """
  Gets the mode of the specified `structured_io`.
  """
  @doc since: "0.5.0"
  @callback mode(structured_io :: GenServer.server()) :: StructuredIO.mode()

  @doc """
  Reads data from the specified `structured_io` in the specified quantity, or
  beginning with the specified binary value.
  """
  @doc since: "1.1.0"
  @callback read(
              structured_io :: GenServer.server(),
              count_or_match :: StructuredIO.count() | StructuredIO.match(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the occurrence of the specified `right` that
  corresponds to it, inclusive.
  """
  @doc since: "0.1.0"
  @callback read_across(
              structured_io :: GenServer.server(),
              left :: StructuredIO.left(),
              right :: StructuredIO.right(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the first occurrence of the specified `right`,
  inclusive.
  """
  @doc since: "0.7.0"
  @callback read_across_ignoring_overlap(
              structured_io :: GenServer.server(),
              left :: StructuredIO.left(),
              right :: StructuredIO.right(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the occurrence of the specified `right` that
  corresponds to it, exclusive.
  """
  @doc since: "0.2.0"
  @callback read_between(
              structured_io :: GenServer.server(),
              left :: StructuredIO.left(),
              right :: StructuredIO.right(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Reads data from the specified `structured_io` beginning with the specified
  `left` and ending with the first occurrence of the specified `right`,
  exclusive.
  """
  @doc since: "0.7.0"
  @callback read_between_ignoring_overlap(
              structured_io :: GenServer.server(),
              left :: StructuredIO.left(),
              right :: StructuredIO.right(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Invokes the specified `operation`, changing the state of the specified
  `structured_io` only if the `operation` is successful. Success is indicated
  when the `operation` returns `{:ok, term}`, in which case only the `term` is
  returned.
  """
  @doc since: "1.2.0"
  @callback read_complex(
              structured_io :: GenServer.server(),
              operation :: StructuredIO.operation(),
              timeout :: timeout
            ) :: any

  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `right` is encountered, including `right`.
  """
  @doc since: "0.2.0"
  @callback read_through(
              structured_io :: GenServer.server(),
              right :: StructuredIO.right(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Reads data from the specified `structured_io` if and until the specified
  `right` is encountered, excluding `right`.
  """
  @doc since: "0.2.0"
  @callback read_to(
              structured_io :: GenServer.server(),
              right :: StructuredIO.right(),
              timeout :: timeout
            ) :: StructuredIO.match() | StructuredIO.error()

  @doc """
  Starts a `StructuredIO` process without links (outside a supervision tree) with
  the specified `mode` and `options`.
  """
  @doc since: "0.5.0"
  @callback start(
              mode :: StructuredIO.mode(),
              options :: GenServer.options()
            ) :: GenServer.on_start()

  @doc """
  Starts a `StructuredIO` process linked to the current process with the
  specified `mode` and `options`.
  """
  @doc since: "0.5.0"
  @callback start_link(
              mode :: StructuredIO.mode(),
              options :: GenServer.options()
            ) :: GenServer.on_start()

  @doc """
  Stops the specified `structured_io` process.
  """
  @doc since: "0.1.0"
  @callback stop(
              structured_io :: GenServer.server(),
              reason :: term,
              timeout :: timeout
            ) :: :ok

  @doc """
  Writes the specified `data` to the specified `structured_io`.
  """
  @doc since: "0.1.0"
  @callback write(
              structured_io :: GenServer.server(),
              data ::
                iodata
                | IO.chardata()
                | String.Chars.t()
            ) :: :ok | StructuredIO.error()
end
