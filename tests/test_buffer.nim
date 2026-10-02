import std/unittest

import pkg/jscompat/npointer
import vsyncio as nio

import ./utils

suite "buffer":
  const filename = when defined(deno):
    "tempfiletest_buffer_deno"
  else:
    "tempfiletest_buffer_node"

  tearDown:
    removeFile(filename)

  test "NPointer buffer IO and EOF":

    let source = alloc0(5)
    for i, c in "abcde":
      source.setUint8(i, uint8(ord(c)))

    var writer: nio.File
    require writer.open(filename, fmWrite)
    check writer.writeBuffer(source, 5) == 5
    writer.close()

    let dest = alloc0(7)
    var reader: nio.File
    require reader.open(filename, fmRead)
    check not reader.endOfFile()
    check reader.readBuffer(dest, 3) == 3
    check dest.getUint8(0) == uint8(ord('a'))
    check dest.getUint8(1) == uint8(ord('b'))
    check dest.getUint8(2) == uint8(ord('c'))
    check not reader.endOfFile()
    check reader.readBuffer(dest, 7) == 2
    check dest.getUint8(0) == uint8(ord('d'))
    check dest.getUint8(1) == uint8(ord('e'))
    check reader.endOfFile()
    check reader.readBuffer(dest, 7) == 0
    reader.close()

    dealloc source
    dealloc dest
