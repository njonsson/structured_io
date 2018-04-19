# Version history for the *StructuredIO* project

## v1.5.0 and v0.12.0

**Wed 4/18/2018**

* Introduce *StructuredIO.Behaviour* and *StructuredIO.Enumerator.Behaviour* in
  support of mocking via [*Mox*][HexDocs-Plataformatec-Mox]

## v1.4.0 and v0.11.0

**Mon 4/02/2018**

* Enhance *StructuredIO.read/3* to accept either an integer or a binary

## v1.3.0 and v0.10.0

**Mon 2/19/2018**

* Add support for *StructuredIO.read_complex/3* to *StructuredIO.Enumerator*

## v1.2.1 and v0.9.1

**Mon 2/12/2018**

* Introduce *StructuredIO.read_complex/3*

## v1.1.0 and v0.8.0

**Thu 2/08/2018**

* Introduce new functions for reading measured data elements:
  - *StructuredIO.read/2*
  - *StructuredIO.Scanner.scan/3*
* Introduce new supporting types:
  - *StructuredIO.count*
  - *StructuredIO.Scanner.count*
  - *StructuredIO.Scanner.unit*

## v1.0.0

**Thu 1/25/2018**

* Eliminate deprecated <small>API</small>s

## v0.7.0

**Mon 1/22/2018**

* Introduce functions that ignore nesting of enclosed data elements:
  - *StructuredIO.read_across_ignoring_overlaps*
  - *StructuredIO.read_between_ignoring_overlaps*
  - *StructuredIO.Scanner.scan_across_ignoring_overlaps*
  - *StructuredIO.Scanner.scan_between_ignoring_overlaps*
* Alter existing functions to respect nesting of enclosed data elements:
  - *StructuredIO.read_across*
  - *StructuredIO.read_between*
  - *StructuredIO.Scanner.scan_across*
  - *StructuredIO.Scanner.scan_between*
* Add support for a message timeout to the
  [*Enumerable*][HexDocs-Elixir-Enumerable] protocol implementation
* Use the deprecation annotations standard in Elixir v1.6 instead of
  [*Logger*][HexDocs-Elixir-Logger] runtime warnings

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

[HexDocs-Plataformatec-Mox]:             https://hexdocs.pm/mox                                "Plataformatec’s ‘Mox’ library at HexDocs"
[HexDocs-Elixir-Enumerable]:             https://hexdocs.pm/elixir/Enumerable.html             "Elixir’s ‘Enumerable’ protocol at HexDocs"
[HexDocs-Elixir-Logger]:                 https://hexdocs.pm/logger/Logger.html                 "Elixir’s ‘Logger’ module at HexDocs"
[HexDocs-Elixir-Collectable]:            https://hexdocs.pm/elixir/Collectable.html            "Elixir’s ‘Collectable’ protocol at HexDocs"
[HexDocs-Elixir-UnicodeConversionError]: https://hexdocs.pm/elixir/UnicodeConversionError.html "Elixir’s ‘UnicodeConversionError’ exception at HexDocs"
