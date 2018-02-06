defmodule StructuredIO.Enumerator do
  @moduledoc """
  Provides an `Enumerable` implementation for `StructuredIO`. Call
  `StructuredIO.enumerate_with/3`or `StructuredIO.enumerate_with/4` instead of
  invoking this module directly.

  Note that enumeration is not a purely functional operation; it consumes data
  elements from the underlying `StructuredIO` process.

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
      iex> {:ok,
      ...>  enumerator} = StructuredIO.Enumerator.new(%{process: structured_io,
      ...>                                              function: :read_between,
      ...>                                              additional_arguments: ["<elem>",
      ...>                                                                     "</elem>"]})
      iex> Enum.map enumerator, &String.upcase/1
      ["FOO",
       "BAR",
       "BAZ"]
      iex> Enum.map enumerator, &String.upcase/1
      []

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
      iex> {:ok,
      ...>  enumerator} = StructuredIO.Enumerator.new(%{process: structured_io,
      ...>                                              function: :read_between,
      ...>                                              additional_arguments: ["<elem>",
      ...>                                                                     "</elem>"]})
      iex> Enum.count enumerator
      3
      iex> Enum.count enumerator
      0

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
      iex> {:ok,
      ...>  enumerator} = StructuredIO.Enumerator.new(%{process: structured_io,
      ...>                                              function: :read_between,
      ...>                                              additional_arguments: ["<elem>",
      ...>                                                                     "</elem>"]})
      iex> Enum.member? enumerator, "bar"
      true
      iex> Enum.member? enumerator, "foo"
      false
      iex> Enum.member? enumerator, "bar"
      false
      iex> Enum.member? enumerator, "baz"
      false
  """


  # TODO: Consider eliminating needless fields in v2: `:process` and `:additional_arguments`
  defstruct process: nil,
            function: nil,
            timeout: nil,
            additional_arguments: [],
            arguments: nil

  @typedoc """
  A `#{inspect __MODULE__}` struct.
  """
  @type t :: %__MODULE__{process: GenServer.server,
                         function: atom,
                         timeout: nil | timeout,
                         additional_arguments: [any],
                         arguments: [any]}


  defimpl Enumerable do
    # Use the default implementation of Enumerable.count/1.
    def count(_enumerator), do: {:error, __MODULE__}


    # Use the default implementation of Enumerable.member?/2.
    def member?(_enumerator, _element), do: {:error, __MODULE__}


    def reduce(_enumerator, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(enumerator, {:suspend, acc}, fun) do
      {:suspended, acc, &reduce(enumerator, &1, fun)}
    end

    def reduce(enumerator, {:cont, acc}, fun) do
      case apply(StructuredIO, enumerator.function, enumerator.arguments) do
        {:error, _}=error -> {:done, error}
        ""                -> {:done, acc}
        element           -> reduce(enumerator, fun.(element, acc), fun)
      end
    end

    # Use the default implementation of Enumerable.slice/1.
    def slice(_enumerator), do: {:error, __MODULE__}
  end


  @error_process "#{inspect __MODULE__} :process field is required"
  @error_function "#{inspect __MODULE__} :function field must be the name of a #{inspect StructuredIO} public function"


  @doc """
  Builds a new `#{inspect __MODULE__}` for the specified `StructuredIO`
  `process`, `function`, and `additional_arguments` to that function.

  ## Examples

      iex> {:ok,
      ...>  enumerator} = StructuredIO.Enumerator.new(%{process: :a_process,
      ...>                                              function: :read_across,
      ...>                                              additional_arguments: ["<elem>",
      ...>                                                                     "</elem>"]})
      iex> enumerator
      %StructuredIO.Enumerator{process: :a_process,
                               function: :read_across,
                               additional_arguments: ["<elem>",
                                                      "</elem>"],
                               arguments: [:a_process,
                                           "<elem>",
                                           "</elem>"]}

      iex> StructuredIO.Enumerator.new %{function: :read_across,
      ...>                               additional_arguments: ["<elem>",
      ...>                                                      "</elem>"]}
      {:error,
       #{inspect @error_process}}

      iex> StructuredIO.Enumerator.new %{process: :a_process,
      ...>                               additional_arguments: ["<elem>",
      ...>                                                      "</elem>"]}
      {:error,
       #{inspect @error_function}}

      iex> StructuredIO.Enumerator.new %{process: :a_process,
      ...>                               function: "read_across",
      ...>                               additional_arguments: ["<elem>",
      ...>                                                      "</elem>"]}
      {:error,
       #{inspect @error_function}}

      iex> StructuredIO.Enumerator.new %{process: :a_process,
      ...>                               function: :not_a_function}
      {:error,
       "function StructuredIO.not_a_function/1 is undefined or private"}

      iex> StructuredIO.Enumerator.new %{process: :a_process,
      ...>                               function: :read_across}
      {:error,
       "function StructuredIO.read_across/1 is undefined or private"}

      iex> StructuredIO.Enumerator.new %{process: :a_process,
      ...>                               function: :read_across,
      ...>                               additional_arguments: "too-few-args"}
      {:error,
       "function StructuredIO.read_across/2 is undefined or private"}
  """
  @since "0.6.0"
  @spec new(%{process: GenServer.server,
              function: atom,
              additional_arguments: any}) :: {:ok, t} | StructuredIO.error

  def new(%{process: nil}=_enumerator), do: {:error, @error_process}

  def new(%{function: nil}=_enumerator), do: {:error, @error_function}

  def new(%{process: process,
            function: function}=enumerator) when is_atom(function) do
    addl_args = enumerator
                |> Map.get(:additional_arguments)
                |> List.wrap
    function_arity = length(addl_args) + 1
    if function_exported?(StructuredIO, function, function_arity) do
      {:ok,
       struct(__MODULE__, process: process,
                          function: function,
                          additional_arguments: addl_args,
                          arguments: [process | addl_args])}
    else
      {:error,
       "function #{inspect StructuredIO}.#{function}/#{function_arity} is undefined or private"}
    end
  end

  def new(%{process: _, function: _}=_enumerator), do: {:error, @error_function}

  def new(%{function: _}=_enumerator), do: {:error, @error_process}

  def new(%{process: _}=_enumerator), do: {:error, @error_function}

  @doc """
  Sets a timeout for the specified `#{inspect __MODULE__}`.

  ## Examples

      iex> {:ok,
      ...>  enumerator} = StructuredIO.Enumerator.new(%{process: :a_process,
      ...>                                              function: :read_across,
      ...>                                              additional_arguments: ["<elem>",
      ...>                                                                     "</elem>"]})
      iex> enumerator
      %StructuredIO.Enumerator{process: :a_process,
                               function: :read_across,
                               additional_arguments: ["<elem>",
                                                      "</elem>"],
                               arguments: [:a_process,
                                           "<elem>",
                                           "</elem>"]}
      iex> enumerator_with_timeout = StructuredIO.Enumerator.timeout(enumerator,
      ...>                                                           1000)
      %StructuredIO.Enumerator{process: :a_process,
                               function: :read_across,
                               additional_arguments: ["<elem>",
                                                      "</elem>"],
                               arguments: [:a_process,
                                           "<elem>",
                                           "</elem>",
                                           1000],
                               timeout: 1000}
      iex> StructuredIO.Enumerator.timeout enumerator_with_timeout,
      ...>                                 nil
      enumerator
  """
  @since "0.7.0"
  @spec timeout(t, timeout | nil) :: t
  def timeout(%__MODULE__{}=enumerator, timeout) do
    new_arguments = cond do
                      enumerator.timeout && timeout ->
                        List.replace_at enumerator.arguments, -1, timeout
                      timeout ->
                        List.insert_at enumerator.arguments, -1, timeout
                      enumerator.timeout ->
                        List.delete_at enumerator.arguments, -1
                      :else ->
                        enumerator.arguments
                    end
    %{enumerator | arguments: new_arguments, timeout: timeout}
  end
end
