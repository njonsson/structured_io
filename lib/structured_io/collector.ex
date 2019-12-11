defmodule StructuredIO.Collector do
  @moduledoc """
  Provides a `Collectable` implementation for `StructuredIO`. Call
  `StructuredIO.collect/1` instead of invoking this module directly.

  ## Examples

      iex> {:ok,
      ...>  structured_io} = StructuredIO.start_link(:unicode)
      iex> {:ok,
      ...>  collector} = StructuredIO.Collector.new(%{process: structured_io,
      ...>                                            function: :write})
      iex> ["<elem>foo</elem>",
      ...>  "<elem>bar</elem>",
      ...>  "<elem>baz</elem>"]
      ...> |> Enum.into(collector)
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

  @enforce_keys [:process, :function]
  defstruct process: nil, function: nil

  @typedoc """
  A `#{inspect(__MODULE__)}` struct.
  """
  @type t :: %__MODULE__{process: GenServer.server(), function: atom}

  defimpl Collectable do
    def into(original) do
      {original, &collector/2}
    end

    defp collector(collector, {:cont, element}) do
      arguments = [collector.process, element]
      :ok = apply(StructuredIO, collector.function, arguments)
      collector
    end

    defp collector(collector, :done), do: collector

    defp collector(_collector, :halt), do: :ok
  end

  @error_process "#{inspect(__MODULE__)} :process field is required"
  @error_function "#{inspect(__MODULE__)} :function field must be the name of a #{
                    inspect(StructuredIO)
                  } public function"

  @doc """
  Builds a new `#{inspect(__MODULE__)}` for the specified
  `#{inspect(StructuredIO)}` `process` and `function`.

  ## Examples

      iex> {:ok,
      ...>  collector} = StructuredIO.Collector.new(%{process: :a_process,
      ...>                                            function: :write})
      iex> collector
      %StructuredIO.Collector{process: :a_process,
                              function: :write}

      iex> StructuredIO.Collector.new %{function: :write}
      {:error,
       #{inspect(@error_process)}}

      iex> StructuredIO.Collector.new %{process: :a_process}
      {:error,
       #{inspect(@error_function)}}

      iex> StructuredIO.Collector.new %{process: :a_process,
      ...>                              function: :not_a_function}
      {:error,
       "function StructuredIO.not_a_function/2 is undefined or private"}
  """
  @doc since: "0.6.0"
  @spec new(%{process: GenServer.server(), function: atom}) :: {:ok, t} | StructuredIO.error()

  def new(%{process: nil} = _collector), do: {:error, @error_process}

  def new(%{process: _, function: nil} = _collector), do: {:error, @error_function}

  def new(%{process: process, function: function} = _collector) when is_atom(function) do
    function_arity = 2

    if function_exported?(StructuredIO, function, function_arity) do
      {:ok, struct(__MODULE__, process: process, function: function)}
    else
      {:error,
       "function #{inspect(StructuredIO)}.#{function}/#{function_arity} is undefined or private"}
    end
  end

  def new(%{function: _} = _collector), do: {:error, @error_process}

  def new(%{process: _} = _collector), do: {:error, @error_function}
end
