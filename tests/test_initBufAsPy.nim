

import std/unittest

import vsyncio as nio
import vsyncio/extraMeth/m_initBufAsPy

import ./utils

suite "initBufAsPy":
  test "bufSize == 1 on windows":
    when not defined(windows): skip()
    else:
      var f = open(filename, fmWrite)
      defer: removeFile(filename)
      expect ValueError:
        f.initBufAsPy(1)
      f.close

