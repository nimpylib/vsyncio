
import std/unittest

import vsyncio as nio
import vsyncio/extraMeth/m_initBufAsPy
import vsyncio/private/warnings

import ./utils

template expectWarning(w: Warning; body) =
  catch_warnings_it(check it.category == w): body

suite "initBufAsPy":
  test "bufSize == 1":
    var f = open(filename, fmWrite)
    defer: removeFile(filename)
    expectWarning RuntimeWarning:
      f.initBufAsPy(1)
    f.close

