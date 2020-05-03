[
  # These patterns fail to match because they only occur in the event of an
  # exception, and Dialyzer only processes function calls that return a value.
  {"lib/structured_io.ex", :pattern_match, 1_274},
  {"lib/structured_io.ex", :pattern_match, 1_409},
]
