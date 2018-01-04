# Version history for the *StructuredIO* project

## v0.6.0

**Thu 1/04/2018**

* Implement Elixir’s [*Collectable*][HexDocs-Elixir-Collectable]
  protocol for piping data into the process
* Implement Elixir’s [*Enumerable*][HexDocs-Elixir-Enumerable] protocol for
  piping data elements out of the process
* Introduce new backward-compatible types to clarify function arguments and
  returns

## v0.5.0

**Tue 1/02/2018**

* Introduce new *StructuredIO* function *.mode* and deprecate letting its value
  be implied by <small>I</small>/<small>O</small> function calls
* Deprecate *StructuredIO* functions:
  - *.binread_across*
  - *.binread_between*
  - *.binread_through*
  - *.binread_to*
  - *.binwrite*
* Eliminate a warning issued under Elixir v1.6.0

## v0.4.0

**Tue 12/26/2017**

* Introduce new *StructuredIO* functions:
  - *.binread_between*
  - *.read_between*
* Introduce new *StructuredIO.Scanner* function *.scan_between*

## v0.3.0

**Tue 12/26/2017**

* Prevent [*UnicodeConversionError*][HexDocs-Elixir-UnicodeConversionError] in
  *StructuredIO* read-oriented functions, returning an error tuple instead

## v0.2.0

**Fri 12/22/2017**

* Introduce new *StructuredIO* functions:
  - *.binread_through*
  - *.binread_to*
  - *.read_through*
  - *.read_to*
* Introduce new *StructuredIO.Scanner* functions:
  - *.scan_through*
  - *.scan_to*
* Introduce optional timeout arguments to *StructuredIO* read-oriented functions

## v0.1.0

**Thu 12/21/2017**

(First release)

[HexDocs-Elixir-Collectable]:            https://hexdocs.pm/elixir/Collectable.html            "Elixir’s ‘Collectable’ protocol at HexDocs"
[HexDocs-Elixir-Enumerable]:             https://hexdocs.pm/elixir/Enumerable.html             "Elixir’s ‘Enumerable’ protocol at HexDocs"
[HexDocs-Elixir-UnicodeConversionError]: https://hexdocs.pm/elixir/UnicodeConversionError.html "Elixir’s ‘UnicodeConversionError’ exception at HexDocs"
