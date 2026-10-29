

import std/unittest

import vsyncio as nio
import vsyncio/extra/openWithBuffering

import ./utils

suite "openWithBuffering":
  tearDown:
    removeFile(filename)
  test "compiles":
    var f = open(filename, fmWrite, buffering = -1)
    f.close()

  test "runs":
    var f = open(filename, fmWrite, buffering = 3)
    f.write("abc")
    f.close()
    #XXX: how to test?

