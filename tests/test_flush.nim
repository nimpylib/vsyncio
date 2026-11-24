
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
  test "normal":
    defer: removeFile(filename)
    writeF(f)
    f.flush()
    f.close()
  test "after closed":
   when not defined(linux): skip() else:
    # on windows: fflush not indiate error on closed file
    #   as fflose release system-alloc buffer and fflush returns 0 for file with no buffer
    writeF(f)
    f.close()
    expect IOError:
      f.flush()

