defmodule StructuredIO.GenServerTransaction do
  @moduledoc """
  Implements transactional changes to `GenServer` state.

  You can call `transaction/3` directly, but this module is better incorporated
  into a `GenServer` via the `use` directive. Doing so defines a public function
  in your module according to the following `t:options/0`:

  * `:function_name` — the name of the function to be defined in your module;
    defaults to `transaction`
  * `:server_name` — the name of the first parameter in the defined function;
    defaults to `server`
  * `:commit_instruction` — the `t:commit_instruction/0` expected from an
    `t:operation/0` passed to the function; defaults to `:commit`
  * `:append_to_doc` — content to be appended to the defined function’s default
    `@doc` attribute, such as example code
  * `:since` — the version expression to be assigned to the defined function’s
    `@since` attribute

  ## Examples

      iex> defmodule Counter do
      ...>   use GenServer
      ...>   use StructuredIO.GenServerTransaction, server_name: "counter"
      ...>
      ...>
      ...>   def start_link, do: GenServer.start_link(__MODULE__, 0)
      ...>
      ...>
      ...>   def current(counter), do: GenServer.call(counter, :current)
      ...>
      ...>
      ...>   def increment(counter), do: GenServer.call(counter, :increment)
      ...>
      ...>
      ...>   def handle_call(:current, _from, current=state), do: {:reply, current, state}
      ...>
      ...>
      ...>   def handle_call(:increment, _from, current=_state) do
      ...>     new_state = current + 1
      ...>     {:reply, current, new_state}
      ...>   end
      ...>
      ...>
      ...>   def init(argument) when is_integer(argument), do: {:ok, argument}
      ...> end
      iex> {:ok,
      ...>  counter} = Counter.start_link
      iex> Counter.current counter
      0
      iex> Counter.increment counter
      iex> Counter.current counter
      1
      iex> Counter.transaction counter,
      ...>                     fn c ->
      ...>   1 = Counter.current(c)
      ...>
      ...>   Counter.increment c
      ...>   2 = Counter.current(c)
      ...>
      ...>   {:commit, :this_is_a_success}
      ...> end
      :this_is_a_success
      iex> Counter.current counter
      2
      iex> Counter.transaction counter,
      ...>                     fn c ->
      ...>   2 = Counter.current(c)
      ...>
      ...>   Counter.increment c
      ...>   3 = Counter.current(c)
      ...>
      ...>   {:this, :is, :a, :failure}
      ...> end
      {:this, :is, :a, :failure}
      iex> Counter.current counter
      2
  """


  @typedoc """
  The label of a tuple returned from `t:operation/0` that indicates it was
  successful.
  """
  @type commit_instruction :: atom


  @typedoc """
  A function around which transactional behavior will be wrapped.
  """
  @type operation :: (GenServer.server -> {commit_instruction, any} | any)


  @typedoc """
  Option values used in defining a transaction function.
  """
  @type option :: {:function_name, :atom | binary}          |
                  {:server_name, :atom | binary}            |
                  {:commit_instruction, commit_instruction} |
                  {:append_to_doc, binary}                  |
                  {:since, Version.version}


  @typedoc """
  Options used in defining a transaction function.
  """
  @type options :: [option]


  defmacro __using__(options) do
    function_name = options
                    |> Keyword.get(:function_name, "transaction")
                    |> to_string
                    |> String.to_atom

    server_name = options
                  |> Keyword.get(:server_name, "server")
                  |> to_string
                  |> String.to_atom
    # This is Elixir AST for a bareword.
    server_name_barename = {server_name, [], Elixir}

    commit_instruction = Keyword.get(options, :commit_instruction, :commit)

    append_to_doc = Keyword.get(options, :append_to_doc)
    doc = """
    Invokes the specified `operation`, changing the state of the specified
    `#{server_name}` only if the `operation` is successful. Success is indicated
    when the `operation` returns `{#{inspect commit_instruction}, term}`, in
    which case only the `term` is returned.

    **Note:** Within the `operation`, you must not send messages to the
    `#{server_name}`. Send messages instead to the `t:GenServer.server/0` which
    is an argument to the `operation`.#{append_to_doc}
    """

    since_assignment = case Keyword.get(options, :since) do
      nil ->
        []
      since ->
        # This is Elixir AST for a module attribute assignment.
        {:@,
         [context: Elixir, import: Kernel],
         [{:since, [context: Elixir], [since]}]}
    end

    quote do
      @typedoc """
      A function around which `#{unquote function_name}/3` behavior will be
      wrapped.
      """
      @type operation :: (GenServer.server -> {unquote(commit_instruction), any} |
                                              any)

      @doc unquote(doc)
      unquote(since_assignment)
      @spec unquote(function_name)(GenServer.server, operation, timeout) :: any
      def unquote(function_name)(unquote(server_name_barename),
                                 operation,
                                 timeout \\ 5000) do
        unquote(__MODULE__).transaction unquote(server_name_barename),
                                        unquote(commit_instruction),
                                        operation,
                                        timeout
      end

      # Explicitly delegate because `defdelegate` does not support
      # pattern-matching beyond arity.
      def handle_call({:transaction, commit_instruction, operation}=request,
                      from,
                      state) do
        unquote(__MODULE__).handle_call request, from, state
      end
    end
  end


  @doc """
  Invokes the specified `operation`, changing the state of the specified `server`
  only if the `operation` is successful. Success is indicated when the
  `operation` returns `{commit_instruction, term}` (where `commit_instruction` is
  as specified), in which case only the `term` is returned.

  **Note:** Within the `operation`, you must not send messages to the `server`.
  Send messages instead to the `t:GenServer.server/0` which is an argument to the
  `operation`.
  """
  @since "1.2.0"
  @spec transaction(GenServer.server,
                    commit_instruction,
                    operation,
                    timeout) :: any
  def transaction(server, commit_instruction, operation, timeout \\ 5000) do
    request = {:transaction, commit_instruction, operation}
    GenServer.call server, request, timeout
  end


  @doc false
  @spec handle_call({:transaction, commit_instruction, operation},
                    GenServer.from,
                    any) :: {:reply, any, any}
  def handle_call({:transaction, commit_instruction, operation}, _from, state) do
    server_clone = clone_server(state)
    {reply, new_state} = try do
                           case operation.(server_clone) do
                             {^commit_instruction, successful_result} ->
                               {successful_result, get_state(server_clone)}
                             unsuccessful_result ->
                               {unsuccessful_result, state}
                           end
                         after
                           GenServer.stop server_clone
                         end
    {:reply, reply, new_state}
  end


  @spec clone_server(any) :: pid
  defp clone_server(state) do
    module = get_module()
    {:ok, pid} = GenServer.start_link(module, state)
    pid
  end


  @spec get_module :: module
  defp get_module do
    {module, :init, _} = Process.get(:"$initial_call")
    module
  end


  @spec get_state(GenServer.server) :: any
  defp get_state(server), do: :sys.get_state(server)
end
