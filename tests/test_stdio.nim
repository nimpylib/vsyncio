import std/unittest

import vsyncio as nio
import vsyncio/extraMeth/m_isatty

test "standard streams":
  check nio.stdin.getFileHandle.int == 0
  check nio.stdout.getFileHandle.int == 1
  check nio.stderr.getFileHandle.int == 2
  #check nio.stdin.read(0) == ""
  #check nio.stdout.write("") == 0
  #check nio.stderr.write("") == 0
  check nio.stdin.isatty() in {false, true}
  check nio.stdout.isatty() in {false, true}
  check nio.stderr.isatty() in {false, true}
  #check nio.stdout.write("stdout") == 6
  #check nio.stdout.write("stdout\n") == 7
  #check nio.stdout.write("stdout stream works\n") == 20
  #check nio.stderr.write("stderr stream works\n") == 20
  nio.stdout.flushFile()
  nio.stderr.flushFile()
  nio.stdout.writeLine("stdout writeLine works")
  nio.stderr.writeLine("stderr writeLine works")

when defined(js) and defined(testStdinReadLine):
  test "read standard input lines":
    nio.stdout.writeLine("stdin-ready-1")
    check nio.stdin.readLine() == "first"
    nio.stdout.writeLine("stdin-ready-2")
    check nio.stdin.readLine() == "second"
    nio.stdout.writeLine("stdin-ready-3")
    check nio.stdin.readLine() == "last"
    nio.stdout.writeLine("stdin-ready-eof")
    expect EOFError:
      discard nio.stdin.readLine()
