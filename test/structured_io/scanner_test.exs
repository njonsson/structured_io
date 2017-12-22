defmodule StructuredIO.ScannerTest do
  use ExUnit.Case
  doctest StructuredIO.Scanner

  alias StructuredIO.Scanner

  @tag :slow
  describe ".scan_across/3" do
    test "with a large binary dataset" do
      opener = <<0, 0, 0>>
      closer = <<255, 255, 255>>
      scan_data = opener                                          <>
                  String.duplicate(<<0, 0, 0, 1, 2, 3>>, 524_288) <>
                  closer
      assert Scanner.scan_across(scan_data, opener, closer) == {scan_data, ""}
    end
  end
end
