## Raw (unbuffered) binary IO, mirroring Python's `io.RawIOBase` and `io.FileIO`.
##
## `FileIO` is the concrete raw file. A `seekable` file does positioned
## reads/writes (so the buffered layer can track the position itself); the
## standard streams are non-seekable and are read/written sequentially.

import std/jsffi

import pkg/handy_sugars/assumes

import ../private/jsutils
import ./private/helpers
import ./iobase

type FileHandle = iobase.FileHandle  # shadow system's syncio.FileHandle

type
  RawIOBase* = ref object of IOBase
    name*: string
    fd*: FileHandle
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

proc newFileIO*(fd: FileHandle, seekable: bool, name: string,
    writable, append: bool): FileIO =
  ## For NodeJs backend. As Deno doesn't has file handle API since v2
  NodeFileIO(fd: fd, seekable: seekable, name: name,
    writable: writable, append: append)

proc newDenoFileIO*(denoFile: JsObject, seekable: bool, name: string,
    writable, append: bool, fd = FileHandle(-1)): FileIO =
  DenoFileIO(fd: fd, denoFile: denoFile, seekable: seekable,
    name: name, writable: writable, append: append)

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
    result = denoWriteSync(f.denoFile, denoBufSlice(buf, offset))

method getFileSize*(f: NodeFileIO): int64 =
  jsTryAsIOError:
    result = int64(jsFstatSize(fsFstatSync(f.fd.cint)))

method getFileSize*(f: DenoFileIO): int64 =
  jsTryAsIOError:
    result = int64(denoSeekSync(f.denoFile, 0, 2))

method flushFile*(f: NodeFileIO) {.raises: [].} =
  if not f.seekable or f.writable:
    jsTryDiscard:
      fsFsyncSync(f.fd.cint)

method flushFile*(f: DenoFileIO) {.raises: [].} =
  if f.seekable:
    if f.writable:
      jsTryDiscard:
        denoSync(f.denoFile)
  else:
    jsTryDiscard:
      denoSyncIfSupported(f.denoFile)

method close*(f: NodeFileIO) {.raises: [].} =
  if f.fd.cint < 0: return  # never close closed. reentrant
  jsTryDiscard:
    fsCloseSync(f.fd.cint)
  f.fd = FileHandle -1

method close*(f: DenoFileIO) {.raises: [].} =
  if f.denoFile.isUndefined: return
  jsTryDiscard:
    denoClose(f.denoFile)
  f.denoFile = jsUndefined
  f.fd = FileHandle -1
