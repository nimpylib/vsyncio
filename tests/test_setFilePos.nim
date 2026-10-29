
import std/unittest

import vsyncio as nio
import ./utils

suite "setFilePos":
  tearDown:
    removeFile(filename)

  test "backend dispatch through RawIOBase, seeking and close":

    var file: nio.File
    require file.open(filename, fmReadWrite)
    file.write("abcde")
    file.flushFile()

    file.setFilePos(1)
    check file.readChar() == 'b'
    file.setFilePos(-1, fspEnd)
    check file.readChar() == 'e'
    file.setFilePos(2)
    file.write("X")
    file.setFilePos(0)
    check file.readAll() == "abXde"
    file.close()

  test "append dispatch ignores logical file position":
    var file: nio.File
    require file.open(filename, fmWrite)
    file.write("abc")
    file.close()
    require file.open(filename, fmAppend)
    file.setFilePos(0)
    file.write("de")
    file.close()
    require file.open(filename, fmRead)
    check file.readAll() == "abcde"
    file.close()
