# StructuredIO

_StructuredIO_ resembles Elixir’s [_IO_][Elixir-IO] module. The difference is
that whereas _IO_ can handle a stream of bytes or lines, _StructuredIO_ can
handle a stream of structured data, such as markup or other application data.

You may find _StructuredIO_ useful for reassembling application data that
arrives in streaming fashion over TCP.

## Example usage

Here’s a contrived example that shows how to read structured data from a stream.
This example depicts Unicode data, but binary data of any kind can be read and
written with the `binread_across/3` and `binwrite/2` functions.

```elixir
iex> {:ok, structured_io} = StructuredIO.start_link
```

Now we have a running _StructuredIO_ process.

```elixir
iex> StructuredIO.write structured_io,
...>                    "  <p>foo</p"
:ok
```

We’ve written some markup to the stream. Note that the `<p>` element is preceded
by whitespace and is not properly closed.

```elixir
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
""
```

No `<p>` element is read because the stream doesn’t begin with a `<p>`.

```elixir
iex> StructuredIO.read_to structured_io,
...>                      "<p>"
"  "
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
""
```

We managed to get past the whitespace, but no `<p>` element is read because the
stream doesn’t contain a complete element.

```elixir
iex> StructuredIO.write structured_io,
...>                    "><hr /><p>bar</p>"
:ok
```

Now the first element is properly closed, and a second complete element has been
written to the stream.

```elixir
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
"<p>foo</p>"
iex> StructuredIO.read_through structured_io,
...>                           "<hr />"
"<hr />"
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
"<p>bar</p>"
```

We’ve read one element at a time from the available data in the stream.

```elixir
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
""
```

No more elements can be read unless more data is written to the stream.

```elixir
iex> StructuredIO.stop structured_io
:ok
```

Don’t forget to stop the process when you’re finished reading from the stream.

You’ll find more detailed examples in the documentation for the _StructuredIO_
module.

## Installation

The package can be installed by adding `:structured_io` to the list of
dependencies in your project’s _mix.exs_ file:

```elixir
def deps do
  [
    {:structured_io, "~> 0.1.0"}
  ]
end
```

## Contributing

After cloning the repository, `mix deps.get` to install dependencies. Then `mix
test` to run the tests. You can also `iex` to get an interactive prompt that
will allow you to experiment.

To release a new version:

1. Update the project history in _History.md_, and then commit.
2. Update the version number in _mix.exs_ and in all package definitions,
   respecting [Semantic Versioning][Semantic-Versioning], and then commit.
3. Tag with a name like `vMAJOR.MINOR.PATCH` corresponding to the new version,
   and then push commits and tags.

## License

Released under the MIT License.

[Elixir-IO]:           https://hexdocs.pm/elixir/IO.html "Elixir’s ‘IO’ module at HexDocs"
[Semantic-Versioning]: http://semver.org/
