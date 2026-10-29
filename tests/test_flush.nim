
import std/unittest

import vsyncio as nio
import vsyncio/extraMeth/m_flush

import ./utils

template writeF(f) {.dirty.} =
  writeFileAs f, "test"
suite "flush stdio":
  test "stdout":
    nio.stdout.flush()
suite "flush":
  tearDown:
    removeFile(filename)
  test "normal":
    writeF(f)
    f.flush()
    f.close()
  test "after closed":
    writeF(f)
    f.close()
    expect OSError:
      f.flush()

