## Buffered binary IO, mirroring Python's `io.BufferedIOBase` and its
## `io.BufferedReader`, `io.BufferedWriter`, `io.BufferedRandom` subclasses.
##
## A buffered stream wraps a raw `RawIOBase` and tracks the logical position
## (`basePos`) itself, reading/writing it in `JS_READ_BUF_SIZE` chunks.

import std/jsffi

import pkg/jscompat/utils/jsencodings

import ../private/jsbuf
import ./iobase
import ./rawio

export iobase.FileHandle
type FileHandle = iobase.FileHandle  # shadow system's syncio.FileHandle

const JS_READ_BUF_SIZE = 8192

{.pragma: bIO, raises: [IOError].}

type
  BufferedIOBase* = ref object of IOBase
    raw*: RawIOBase
    basePos: int64  # pos when read-buffer is inactive
    # read-buffer, used for getFilePos consistency
    rbuf: TypedArray[uint8, ArrayBuffer]
    rbufValid: bool
    rbufLen: cint
    rbufPos: cint
    rbufStart: int64
    # 1-char pushback, used by `pyio_open.peekChar`
    hasPB: bool
    pb: char

method getFileHandle*(f: BufferedIOBase): FileHandle {.raises: [].} =
  IOBase(f.raw).getFileHandle()
method isatty*(f: BufferedIOBase): bool =
  IOBase(f.raw).isatty()

using f: BufferedIOBase
proc discardRbuf(f) =
  f.hasPB = false
  if f.rbufValid:
    f.basePos = f.rbufStart + int64(f.rbufPos)
    f.rbufValid = false

method getFilePos*(f): int64 =
  if f.rbufValid: f.rbufStart + int64(f.rbufPos)
  else: f.basePos

proc fillRbuf(f): bool {.raises: [IOError].} =
  if not f.rbufValid:
    f.rbuf = newUint8Array(JS_READ_BUF_SIZE.cint)
    f.rbufValid = true
  let n = f.raw.readBuffer(f.rbuf, f.basePos)
  if n <= 0: return false
  f.rbufStart = f.basePos
  f.rbufLen = n
  f.rbufPos = 0
  f.basePos += int64(n)
  result = true

method readChar*(f): char {.bIO.} =
  if f.hasPB:
    f.hasPB = false
    inc f.rbufPos
    return f.pb
  if not f.rbufValid or f.rbufPos >= f.rbufLen:
    if not f.fillRbuf():
      raise newException(EOFError, "readChar got EOF")
  result = chr f.rbuf[f.rbufPos]
  inc f.rbufPos

proc pushCharBack*(f; c: char) =
  f.hasPB = true
  f.pb = c
  if f.rbufValid and f.rbufPos > 0:
    dec f.rbufPos

proc readChars*(f; dst: var openArray[char], startIndex = 0): int =
  var i = startIndex
  while i < dst.len:
    try:
      dst[i] = f.readChar()
    except EOFError:
      break
    inc i
  result = i - startIndex

method readAll*(f): string {.bIO.} =
  var tmp: array[64 * 1024, char]
  while true:
    let n = f.readChars(tmp, 0)
    if n <= 0: break
    for i in 0..<n: result.add tmp[i]

method readLine*(f): string {.bIO.} =
  while true:
    try:
      let c = f.readChar()
      if c == '\n':
        if result.len > 0 and result[^1] == '\r':
          result.setLen(result.len - 1)
        return
      result.add c
    except EOFError:
      if result.len == 0:
        raise
      return

proc write(f; buf: TypedArray[uint8, auto]) =
  if buf.len == 0: return
  f.discardRbuf()
  let total = buf.length
  var written: cint = 0
  block writeBlock:
    while written < total:
      let w = f.raw.writeBuffer(buf, written, total - written,
        f.basePos + int64(written))
      if w <= 0: break writeBlock
      written += w
  if not f.raw.append:
    f.basePos += int64(written)

method write*(f; c: char) {.bIO.} =
  let a = newUint8Array(1)
  a[0] = cast[uint8](c)
  f.write a
method write*(f; s: string) {.bIO.} =
  f.write toUint8Array(s)
method write*(f; s: cstring) {.bIO.} =
  f.write newTextEncoder().encode(s)

method writeLine*(f; s: string) {.bIO.} =
  f.write s
  f.write "\p"

method setFilePos*(f; pos: int64,
    rel: FileSeekPos = fspSet) {.bIO.} =
  if not f.raw.seekable:
    raise newException(IOError, "cannot set file position")
  f.discardRbuf()
  case rel
  of fspSet:
    f.basePos = pos
  of fspCur:
    f.basePos = f.basePos + pos
  of fspEnd:
    f.basePos = f.raw.getFileSize() + pos

method flushFile*(f) {.raises: [].} =
  f.raw.flushFile()

method close*(f) {.raises: [].} =
  f.raw.close()

