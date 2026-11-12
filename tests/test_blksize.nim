
import std/unittest

import vsyncio as nio
import vsyncio/extraMeth/m_getBlkSize

import ./utils

template writeF(f) {.dirty.} =
  writeFileAs f, "test"
suite "getBlkSize":
  tearDown:
    removeFile(filename)
  test "compiles":
    writeF(f)
    try:
      check f.getBlkSize() > 0
    except OSError: discard
    f.close()

