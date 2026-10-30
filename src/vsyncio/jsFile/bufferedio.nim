## Buffered binary IO, mirroring Python's `io.BufferedIOBase` and its
## `io.BufferedReader`, `io.BufferedWriter`, `io.BufferedRandom` subclasses.
##
## A buffered stream wraps a raw `RawIOBase` and tracks the logical position
## (`basePos`) itself, reading/writing it in `buffering` chunks;
## reads are served from `rbuf` (refilled from `raw`), writes go into `wbuf`
## and are written out to `raw` once they fill it up, 
## or on `flush`/`setFilePos`/`close`.

import std/jsffi

import pkg/jscompat/utils/[
  jsencodings, jsdataview, jstypedarrays,
]
import pkg/jscompat/npointer

import ../private/jsbuf
import ./iobase
import ./rawio

export iobase.FileHandle
type FileHandle = iobase.FileHandle  # shadow system's syncio.FileHandle

const JS_BUF_SIZE = 8192

{.pragma: bIO, raises: [IOError].}

type
  BufferedIOBase* = ref object of IOBase
    raw*: RawIOBase
    bufLen = JS_BUF_SIZE.cint
    basePos: int64  # pos when read-buffer is inactive
    # read-buffer, used for getFilePos consistency
    rbuf: TypedArray[uint8, ArrayBuffer]
    rbufValid: bool
    rbufLen: cint  ## bytes read currently
    rbufPos: cint
    rbufStart: int64
    # write-buffer, holding pending write data until filled or flushed
    wbuf: TypedArray[uint8, ArrayBuffer]
    wbufLen: cint  ## bytes pending in `wbuf`
    # 1-char pushback, used by `pyio_open.peekChar`
    hasPB: bool
    pb: char

proc new*[F: BufferedIOBase](raw: RawIOBase): F =
  F(raw: raw)

method initBufAsPy*(f: BufferedIOBase; buf: int) =
  case buf
  of 0:
    raise newException(ValueError, "buffer size cannot be 0 for BufferedIOBase")
  of 1:
    raise newException(ValueError,
      "BufferedIOBase: " & nonTextNoLineBuffering)
  elif buf < 0: return # use default
  else:
    f.bufLen = buf

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
  else: f.basePos + int64(f.wbufLen)

proc flushWbuf(f) {.raises: [IOError].} =
  ## write out the pending data held in `wbuf` and reset it
  if f.wbufLen <= 0: return
  var written: cint = 0
  while written < f.wbufLen:
    let w = f.raw.writeBuffer(f.wbuf, written, f.wbufLen - written,
      f.basePos + int64(written))
    if w <= 0: break
    inc written, w
  if not f.raw.append:
    f.basePos += int64(f.wbufLen)
  f.wbufLen = 0

proc fillRbufImpl(f): bool =
  if not f.rbufValid:
    f.rbuf = newUint8Array(f.bufLen)
    f.rbufValid = true
  let n = f.raw.readBuffer(f.rbuf, f.basePos)
  if n <= 0: return false
  f.rbufStart = f.basePos
  f.rbufLen = n
  f.rbufPos = 0
  f.basePos += int64(n)
  result = true

template fillRbuf(f): bool =
  f.flushWbuf()  # like std/syncio, reading flushes the pending writes
  f.fillRbufImpl()

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

method readBuffer*(f; buffer: NPointer; len: Natural): int {.bIO.} =
  try:
    while result < len:
      buffer.setUint8(result, cast[uint8](f.readChar()))
      inc result
  except EOFError:
    discard

method endOfFile*(f): bool {.raises: [].} =
  try:
    let c = f.readChar()
    f.pushCharBack(c)
  except EOFError:
    return true
  except IOError:
    #XXX: Nim's std/syncio ignore endOfFile's IOError
    return true

method pushCharBack*(f; c: char) =
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

proc write(f; buf: TypedArray[uint8, auto]): int =
  if buf.len == 0: return
  f.discardRbuf()
  let total = buf.length
  var written: cint = 0
  block writeBlock:
    while written < total:
      let remain = total - written
      if f.wbufLen == 0 and remain >= f.bufLen:
        # bypass the buffer for data capable to fill it wholly,
        #   like CPython's BufferedWriter does
        let w = f.raw.writeBuffer(buf, written, remain, f.basePos)
        if w == 0: break writeBlock
        inc written, w
        if not f.raw.append:
          f.basePos += int64(w)
      else:
        if f.wbuf.isNil:
          f.wbuf = newUint8Array(f.bufLen)
        let chunk = min(remain, f.bufLen - f.wbufLen)
        f.wbuf.set(buf.subarray(written, written + chunk), f.wbufLen)
        inc written, chunk
        inc f.wbufLen, chunk
        if f.wbufLen == f.bufLen:
          f.flushWbuf()
  result = written.int

method write*(f; c: char) {.bIO.} =
  f.discardRbuf()
  if f.wbuf.isNil:
    f.wbuf = newUint8Array(f.bufLen)
  f.wbuf[f.wbufLen] = cast[uint8](c)
  inc f.wbufLen
  if f.wbufLen == f.bufLen:
    f.flushWbuf()
method write*(f; s: string) {.bIO.} =
  discard f.write(toUint8Array(s))
method write*(f; s: cstring) {.bIO.} =
  discard f.write(newTextEncoder().encode(s))

method writeBuffer*(f; buffer: NPointer; len: Natural): int {.bIO.} =
  buffer.asDataViewIt:
    assert len <= it.len
    let data = newUint8Array(it.buffer, 0, cint len)
    result = f.write(data)

method writeLine*(f; s: string) {.bIO.} =
  f.write s
  f.write "\p"

method setFilePos*(f; pos: int64,
    rel: FileSeekPos = fspSet) {.bIO.} =
  if not f.raw.seekable:
    raise newException(IOError, "cannot set file position")
  f.flushWbuf()  # stranded pending data otherwise
  f.discardRbuf()
  case rel
  of fspSet:
    f.basePos = pos
  of fspCur:
    f.basePos = f.basePos + pos
  of fspEnd:
    f.basePos = f.raw.getFileSize() + pos

method getFileSize*(f): int64 =
  # flush so the buffered writes are accounted for
  #   (they land before the size is measured)
  f.flushWbuf()
  f.raw.getFileSize

method flush*(f)  =
  ## flush pending data.
  f.flushWbuf()
  f.raw.flush()

method close*(f) {.raises: [].} =
  # as std/syncio, `close` flushes first, swallowing errors
  f.flushFile()
  f.raw.close()

