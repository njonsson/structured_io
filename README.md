# StructuredIO

[<img alt="Travis CI build status" src="https://secure.travis-ci.org/njonsson/structured_io.svg?branch=master" />][Travis-CI-build-status]
[<img alt="Coveralls test coverage status" src="https://coveralls.io/repos/njonsson/structured_io/badge.svg?branch=master" />][Coveralls-test-coverage-status]
[<img alt="Hex release" src="https://img.shields.io/hexpm/v/structured_io.svg" />][Hex-release]

*StructuredIO* resembles Elixir’s [*IO*][HexDocs-Elixir-IO] module. The
difference is that whereas *IO* exposes a freeform stream of bytes or lines of
data, *StructuredIO* guarantees that only complete data elements are returned
from its reader functions. This simplifies your application logic with respect
to fragmentary input.

There are two main features of this library:

1. **It provides a stateful process with a writer function for writing binary
   data.** (No big deal since *IO* gives you that.)
2. **It provides a variety of reader functions for conditional reading according
   to a specified data structure.** Virtually any wire format can be specified,
   including binary encodings, nested and flat markup, and delimited data. If a
   complete data element has not (yet) been written to the process, nothing is
   read.

**See what’s changed lately by reading
[the project history][GitHub-project-history].**

## Usage

Here’s a contrived example that shows how to write and read structured data
using the `StructuredIO.write` and `.read_*` functions. This example depicts
Unicode data, but binary data of any kind can be written and read, too. See
[the API reference][HexDocs-project-API-reference] for detailed examples.

```elixir
iex> {:ok,
...>  structured_io} = StructuredIO.start_link(:unicode)
```

Now we have a running *StructuredIO* process that expects properly encoded
Unicode data.

```elixir
iex> StructuredIO.write structured_io,
...>                    "  <p>foo</p"
:ok
```

We’ve written some markup to the process. Note that the `<p>` element is
preceded by whitespace and is not properly closed.

```elixir
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
""
```

No `<p>` element is read because the available data in the process doesn’t begin
with a `<p>`.

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
available data in the process doesn’t contain a complete element.

```elixir
iex> StructuredIO.write structured_io,
...>                    "><hr /><p>bar</p>"
:ok
```

Now the first element is properly closed, and a second complete element has been
written to the process.

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

We’ve read one element at a time from the available data in the process. The
read operations demonstrate both seeking and skipping.

```elixir
iex> StructuredIO.read_across structured_io,
...>                          "<p>",
...>                          "</p>"
""
```

No more elements can be read unless more data is written to the process.

```elixir
iex> collector = StructuredIO.collect(structured_io)
iex> ["<p>baz</p>",
...>  "<p>qux</p>",
...>  "<p>quux</p>"]
...> |> Enum.into(collector)
iex> structured_io
...> |> StructuredIO.enumerate_with(:read_between,
...>                                "<p>",
...>                                "</p>")
...> |> Enum.map(&String.upcase/1)
["BAZ",
 "QUX",
 "QUUX"]
```

The `StructuredIO.collect` function returns a struct that implements Elixir’s
[*Collectable*][HexDocs-Elixir-Collectable] protocol, which lets you **pipe data
into the process** instead of performing individual write operations. Likewise,
the `StructuredIO.enumerate_with` function returns a struct that implements
Elixir’s [*Enumerable*][HexDocs-Elixir-Enumerable] protocol, which lets you
**pipe data elements out of the process** instead of performing individual read
operations.

```elixir
iex> StructuredIO.stop structured_io
:ok
```

Don’t forget to stop the process when you’re finished with it.

You’ll find more detailed examples in
[the documentation][HexDocs-project-API-reference] for the *StructuredIO*
module.

## Installation

Install [the Hex package][Hex-release] by adding `:structured_io` to the list of
dependencies in your project’s *mix.exs* file:

```elixir
# mix.exs

# ...
def deps do
  [
    {:structured_io, "~> 1.3.0"}
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
`mix test` to run the tests. You can also `iex -S mix` to get an interactive
prompt that will allow you to experiment. To build this package,
`mix hex.build`.

To release a new version:

1. Update [the project history in *History.md*][GitHub-project-history], and
   then commit.
2. Update the version number in [*mix.exs*][GitHub-mix-dot-exs-file] respecting
   [Semantic Versioning][Semantic-Versioning], update
   [the “Installation” section](#installation) of
   [this readme][GitHub-readme-dot-md-file] to reference the new version, and
   then commit.
3. Build and publish [the Hex package][Hex-release] with `mix hex.publish`.
4. Tag with a name like `vMAJOR.MINOR.PATCH` corresponding to the new version,
   and then push commits and tags.

## License

Released under the [MIT License][GitHub-project-MIT-License].

[Travis-CI-build-status]:          https://www.travis-ci.org/njonsson/structured_io                             "Travis CI build status for ‘StructuredIO’"
[Coveralls-test-coverage-status]:  https://coveralls.io/r/njonsson/structured_io?branch=master                  "Coveralls test coverage status for ‘StructuredIO’"
[Hex-release]:                     https://hex.pm/packages/structured_io                                        "Hex release of ‘StructuredIO’"
[HexDocs-Elixir-IO]:               https://hexdocs.pm/elixir/IO.html                                            "Elixir’s ‘IO’ module at HexDocs"
[HexDocs-Elixir-Collectable]:      https://hexdocs.pm/elixir/Collectable.html                                   "Elixir’s ‘Collectable’ protocol at HexDocs"
[HexDocs-Elixir-Enumerable]:       https://hexdocs.pm/elixir/Enumerable.html                                    "Elixir’s ‘Enumerable’ protocol at HexDocs"
[HexDocs-project-API-reference]:   https://hexdocs.pm/structured_io/api-reference.html                          "‘StructuredIO’ API reference at HexDocs"
[GitHub-project-history]:          https://github.com/njonsson/structured_io/blob/master/History.md             "‘StructuredIO’ project history at GitHub"
[GitHub-fork-project]:             https://github.com/njonsson/structured_io/fork                               "Fork the official repository of ‘StructuredIO’"
[GitHub-compare-project-branches]: https://github.com/njonsson/structured_io/compare                            "Compare branches of ‘StructuredIO’ repositories"
[GitHub-mix-dot-exs-file]:         https://github.com/njonsson/structured_io/blob/master/mix.exs                "‘StructuredIO’ project ‘mix.exs’ file at GitHub"
[Semantic-Versioning]:             https://semver.org/
[GitHub-readme-dot-md-file]:       https://github.com/njonsson/structured_io/blob/master/README.md#installation "‘StructuredIO’ project ‘README.md’ file at GitHub"
[GitHub-project-MIT-License]:      https://github.com/njonsson/structured_io/blob/master/License.md             "MIT License claim for ‘StructuredIO’ at GitHub"
