# StructuredIO

[<img alt="Travis CI build status" src="https://secure.travis-ci.org/njonsson/structured_io.svg?branch=master" />][Travis-CI-build-status]
[<img alt="HexFaktor dependencies status" src="https://beta.hexfaktor.org/badge/all/github/njonsson/structured_io.svg" />][HexFaktor-deps-status]
[<img alt="Coveralls test coverage status" src="https://coveralls.io/repos/njonsson/structured_io/badge.svg?branch=master" />][Coveralls-test-coverage-status]
[<img alt="Hex release" src="https://img.shields.io/hexpm/v/structured_io.svg" />][Hex-release]

_StructuredIO_ resembles Elixir’s [_IO_][Elixir-IO] module. The difference is
that whereas _IO_ gives you sequential access to a freeform stream of bytes or
lines of data, _StructuredIO_ guarantees that when you read data it conforms to
a structure that you specify. That is to say, only complete data elements are
read, so that your application can more easily handle truncated or streaming
application data.

Among other applications, you may find _StructuredIO_ useful for reassembling
data that arrives in streaming fashion over TCP.

**See what’s changed lately by reading
[the project history][GitHub-project-history].**

## Usage

Here’s a contrived example that shows how to write to and read structured data
using the `StructuredIO.write` and `.read_*` functions. This example depicts
Unicode data, but binary data of any kind can be written and read, too. See
[the API reference][HexDocs-project-API-reference] for detailed examples.

```elixir
iex> {:ok, structured_io} = StructuredIO.start_link(:unicode)
```

Now we have a running _StructuredIO_ process that expects properly encoded
Unicode data.

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
iex> StructuredIO.read_between structured_io,
...>                           "<p>",
...>                           "</p>"
"bar"
```

We’ve read one element at a time from the available data in the stream. The read
operations demonstrate both seeking and skipping.

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

Install [the Hex package][Hex-release] by adding `:structured_io` to the list of
dependencies in your project’s _mix.exs_ file:

```elixir
# mix.exs

# ...
def deps do
  [
    {:structured_io, "~> 0.5.0"}
  ]
end
# ...
```

## Contributing

To submit a patch to the project:

1. [Fork][GitHub-fork-project] the official repository.
2. Create your feature branch: `git checkout -b my-new-feature`.
3. Commit your changes: `git commit -am 'Add some feature'`.
4. Push to the branch: `git push origin my-new-feature`.
5. [Create][GitHub-compare-project-branches] a new pull request.

After cloning the repository, `mix deps.get` to install dependencies. Then
`mix test` to run the tests. You can also `iex` to get an interactive prompt
that will allow you to experiment. To build this package, `mix hex.build`.

To release a new version:

1. Update [the project history in _History.md_][GitHub-project-history], and
   then commit.
2. Update the version number in [_mix.exs_][GitHub-mix-dot-exs-file] respecting
   [Semantic Versioning][Semantic-Versioning], update
   [the “Installation” section](#installation) of
   [this readme][GitHub-readme-dot-md-file] to reference the new version, and
   then commit.
3. Build and publish [the Hex package][Hex-release] with `mix hex.publish`.
4. Tag with a name like `vMAJOR.MINOR.PATCH` corresponding to the new version,
   and then push commits and tags.

## License

Released under the [MIT License][GitHub-project-MIT-License].

[Travis-CI-build-status]:          http://travis-ci.org/njonsson/structured_io                                  "Travis CI build status for ‘StructuredIO’"
[HexFaktor-deps-status]:           https://beta.hexfaktor.org/github/njonsson/structured_io                     "HexFaktor dependencies status for ‘StructuredIO’"
[Coveralls-test-coverage-status]:  https://coveralls.io/r/njonsson/structured_io?branch=master                  "Coveralls test coverage status"
[Hex-release]:                     https://hex.pm/packages/structured_io                                        "Hex release of ‘StructuredIO’"
[Elixir-IO]:                       https://hexdocs.pm/elixir/IO.html                                            "Elixir’s ‘IO’ module at HexDocs"
[HexDocs-project-API-reference]:   https://hexdocs.pm/structured_io/api-reference.html                          "‘StructuredIO’ API reference at HexDocs"
[GitHub-project-history]:          https://github.com/njonsson/structured_io/blob/master/History.md             "‘StructuredIO’ project history"
[GitHub-fork-project]:             https://github.com/njonsson/structured_io/fork                               "Fork the official repository of ‘StructuredIO’"
[GitHub-compare-project-branches]: https://github.com/njonsson/structured_io/compare                            "Compare branches of ‘StructuredIO’ repositories"
[GitHub-mix-dot-exs-file]:         https://github.com/njonsson/structured_io/blob/master/mix.exs                "‘StructuredIO’ project ‘mix.exs’ file"
[Semantic-Versioning]:             http://semver.org/
[GitHub-readme-dot-md-file]:       https://github.com/njonsson/structured_io/blob/master/README.md#installation "‘StructuredIO’ project ‘README.md’ file"
[GitHub-project-MIT-License]:      http://github.com/njonsson/structured_io/blob/master/License.md              "MIT License claim for ‘StructuredIO’"
