defmodule StructuredIO.Enumerator.Behaviour do
  @moduledoc """
  Defines a behavioral contract that is satisfied by `StructuredIO.Enumerator`.
  """


  alias StructuredIO.Enumerator


  @doc """
  Sets a timeout for the specified `#{inspect Enumerator}`. This value is passed
  in each call to the `StructuredIO.read*` function.
  """
  @since "0.7.0"
  @callback timeout(enumerator :: Enumerator.t,
                    timeout :: timeout | nil) :: Enumerator.t
end
