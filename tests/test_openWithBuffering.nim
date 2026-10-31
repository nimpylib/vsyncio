

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

  test "small buffer":
    let s = "abc"
    var f = open(filename, fmWrite, buffering = s.len-1)
    f.write(s)
    f.close()

    check readFileCompat(filename) == s

  test "not write before flush or buffer full-filled":    
    let s = "abcd"
    var f = open(filename, fmWrite, buffering = s.len+1)
    f.write(s)
    check readFileCompat(filename) == ""
    f.close()
    check readFileCompat(filename) == s

