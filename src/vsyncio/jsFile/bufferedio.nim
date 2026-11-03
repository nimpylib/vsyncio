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
  jsdataview, jstypedarrays,
]


import ../private/jsbuf
import ./iobase
import ./rawio

export iobase
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
  F(raw: raw, basePos: raw.getFilePos())

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
  var written = 0
  while written < f.wbufLen:
    let w = f.raw.write(f.wbuf, written, f.wbufLen - written)
    if w <= 0: break
    inc written, w
  f.basePos += int64(written)
  f.wbufLen = 0

proc fillRbufImpl(f): bool {.raises: [IOError].} =
  if not f.rbufValid:
    f.rbuf = newUint8Array(f.bufLen)
    f.rbufValid = true
  let n = f.raw.read(f.rbuf)
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

method read*(f; buffer: TypedArray[uint8, auto]): int {.bIO.} =
  let len = buffer.len
  try:
    while result < len:
      buffer[result] = cast[uint8](f.readChar())
      inc result
  except EOFError:
    discard

method pushCharBack*(f; c: char) =
  f.hasPB = true
  f.pb = c
  if f.rbufValid and f.rbufPos > 0:
    dec f.rbufPos

method readChars*(f; dst: var openArray[char]): int =
  while result < dst.len:
    try:
      dst[result] = f.readChar()
    except EOFError:
      break
    inc result

method write(f; buf: TypedArray[uint8, auto]): int =
  let
    offset = 0
    len = buf.len
  if len == 0: return
  f.discardRbuf()
  var noffset = offset
  block writeBlock:
    while result < len:
      let remain = len - result
      if f.wbufLen == 0 and remain >= f.bufLen:
        # bypass the buffer for data capable to fill it wholly,
        #   like CPython's BufferedWriter does
        let w = f.raw.write(buf, noffset, remain)
        if w <= 0: break writeBlock
        inc result, w
        inc noffset, w
        f.basePos += int64(w)
      else:
        if f.wbuf.isNil:
          f.wbuf = newUint8Array(f.bufLen)
        let chunk = min(remain, f.bufLen - f.wbufLen)
        f.wbuf.set(buf.subarray(noffset, noffset + chunk), f.wbufLen)
        inc result, chunk
        inc noffset, chunk
        inc f.wbufLen, chunk
        if f.wbufLen == f.bufLen:
          f.flushWbuf()

method write*(f; c: char) {.bIO.} =
  f.discardRbuf()
  if f.wbuf.isNil:
    f.wbuf = newUint8Array(f.bufLen)
  f.wbuf[f.wbufLen] = cast[uint8](c)
  inc f.wbufLen
  if f.wbufLen == f.bufLen:
    f.flushWbuf()

method setFilePos*(f; pos: int64,
    rel: FileSeekPos = fspSet) {.bIO.} =
  f.flushWbuf()  # stranded pending data otherwise
  f.discardRbuf()
  f.raw.setFilePos(pos, rel)
  f.basePos = f.raw.getFilePos()

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

