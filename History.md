# Version history for the _StructuredIO_ project

## v0.3.0

**Tue 12/26/2017**

* Prevent _UnicodeConversionError_ in read functions, returning an error tuple
  instead

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
