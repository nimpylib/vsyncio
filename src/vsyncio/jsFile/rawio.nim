## Raw (unbuffered) binary IO, mirroring Python's `io.RawIOBase` and `io.FileIO`.
##
## `FileIO` is the concrete raw file. A `seekable` file does positioned
## reads/writes (so the buffered layer can track the position itself); the
## standard streams are non-seekable and are read/written sequentially.

import std/jsffi

import pkg/handy_sugars/assumes
import pkg/pyerrors/oserr

import ../private/[jsutils, consts]
import ./private/helpers
import ./iobase

type FileHandle = iobase.FileHandle  # shadow system's syncio.FileHandle

type
  RawIOBase* = ref object of IOBase
    name*: string
    fd*: FileHandle
    closed: bool
    seekable*: bool
    writable*: bool
    append*: bool

  FileIO* = ref object of RawIOBase
  NodeFileIO = ref object of FileIO
  DenoFileIO = ref object of FileIO
    denoFile: JsObject

method getFileHandle*(f: RawIOBase): FileHandle {.raises: [].} = f.fd
method getDenoFile*(f: RawIOBase): tuple[f: JsObject, useDeno: bool] {.base, raises: [].} =
  (jsUndefined, false)
method getDenoFile*(f: DenoFileIO): tuple[f: JsObject, useDeno: bool] {.raises: [].} =
  (f.denoFile, true)

proc newFileIO*(fd: FileHandle, name: string, mode: FileMode, seekable: bool,
    ): FileIO =
  ## For NodeJs backend. As Deno doesn't has file handle API since v2
  NodeFileIO(fd: fd, seekable: seekable, name: name,
    writable: mode != fmRead, append: mode == fmAppend)

proc newDenoFileIO*(denoFile: JsObject,
    name: string, mode: FileMode, seekable: bool,
    fd = FileHandle(-1)): FileIO =
  DenoFileIO(fd: fd, denoFile: denoFile, seekable: seekable,
    name: name,
    writable: mode != fmRead, append: mode == fmAppend)

method initBufAsPy*(f: RawIOBase; buf: int) =
  raise newException(ValueError, "cannot setbuf for raw IO")
# Use JsObject for buffers so dispatch stays non-generic for both ordinary
# and shared Uint8Array buffers.
method readBuffer*(f: RawIOBase, buf: JsObject, pos: int64): cint {.base, raises: [IOError].} =
  unreachable

method readBuffer*(f: NodeFileIO, buf: JsObject, pos: int64): cint =
  jsTryAsIOError:
    let len = buf.length.to(cint)
    if f.seekable:
      result = fsReadSync(f.fd.cint, buf, 0, len, cint(pos))
    else:
      result = fsReadSync(f.fd.cint, buf, 0, len)

method readBuffer*(f: DenoFileIO, buf: JsObject, pos: int64): cint =
  jsTryAsIOError:
    if f.seekable:
      discard denoSeekSync(f.denoFile, cint(pos), 0)
    result = denoReadSync(f.denoFile, buf)

method writeBuffer*(f: RawIOBase, buf: JsObject,
    offset, len: cint, pos: int64): cint {.base, raises: [IOError].} =
  unreachable

method writeBuffer*(f: NodeFileIO, buf: JsObject,
    offset, len: cint, pos: int64): cint =
  jsTryAsIOError:
    if f.seekable and not f.append:
      result = fsWriteSync(f.fd.cint, buf, offset, len, cint(pos))
    else:
      result = fsWriteSync(f.fd.cint, buf, offset, len)

method writeBuffer*(f: DenoFileIO, buf: JsObject,
    offset, len: cint, pos: int64): cint =
  jsTryAsIOError:
    if f.seekable and not f.append:
      discard denoSeekSync(f.denoFile, cint(pos), 0)
    result = denoWriteSync(f.denoFile,
      denoBufSliceToEnd(buf, offset, offset + len))

method getFileSize*(f: NodeFileIO): int64 =
  jsTryAsIOError:
    result = int64(jsFstatSize(fsFstatSync(f.fd.cint)))

method getFileSize*(f: DenoFileIO): int64 =
  jsTryAsIOError:
    result = int64(denoSeekSync(f.denoFile, 0, 2))

template flushImpl =
  if f.closed:
    raise newException(IOError, ioOnClosedErrMsg)
template genFlush(flushFile) {.dirty.} =
  method flushFile*(f: NodeFileIO) =
    flushImpl

  method flushFile*(f: DenoFileIO) =
    flushImpl
genFlush flush

template withClosed(f; body) {.dirty.} =
  if f.closed: return  # never close closed. reentrant
  jsTryDiscard:
    body
  f.closed = true

method close*(f: NodeFileIO) {.raises: [].} =
  # we shall not set f.fd to -1 as we need
  #   node to raise error with EBADF errno when acting on closed file
  # otherwise, a
  #   `RangeError: The value of "fd" is out of range. It must be >= 0 && <= 2147483647. Received -1`
  #   will be thrown
  f.withClosed:
    fsCloseSync(f.fd.cint)

method close*(f: DenoFileIO) {.raises: [].} =
  # we shall not set f.denoFile to jsUndefined as we need
  #   with the same reason above.
  f.withClosed:
    denoClose(f.denoFile)

