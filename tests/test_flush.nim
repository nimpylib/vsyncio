
import std/unittest

import vsyncio as nio
import vsyncio/extraMeth/m_flush

import ./utils
const filename =
  "tempfiletest_fileio"

template writeF(f) {.dirty.} =
    var f = nio.open(filename, fmWrite)
    defer:removeFile(filename)
    f.write("test")
block:
    writeF(f)
    f.close()
    f.flush()
suite "flush":
  test "normal":
    writeF(f)
    f.flush()
    f.close()
  test "after closed":
    writeF(f)
    f.close()
    expect OSError:
      f.flush()

