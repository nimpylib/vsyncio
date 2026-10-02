## Raw (unbuffered) binary IO, mirroring Python's `io.RawIOBase` and `io.FileIO`.
##
## `FileIO` is the concrete raw file. A `seekable` file does positioned
## reads/writes (so the buffered layer can track the position itself); the
## standard streams are non-seekable and are read/written sequentially.

import std/jsffi

import ../private/[jsutils, jsbuf]
import ./private//helpers
import ./iobase

type FileHandle = iobase.FileHandle  # shadow system's syncio.FileHandle

type
  RawIOBase* = ref object of IOBase
    fd*: FileHandle
    denoFile: JsObject
    isDenoFile: bool
    seekable*: bool
    name*: string
    writable*: bool
    append*: bool

  FileIO* = ref object of RawIOBase

method getFileHandle*(f: RawIOBase): FileHandle {.raises: [].} = f.fd
proc getDenoFile*(f: RawIOBase): tuple[f: JsObject, useDeno: bool] =
  (f.denoFile, f.isDenoFile)

proc newFileIO*(fd: FileHandle, seekable: bool, name: string,
    writable, append: bool,
    denoFile: JsObject = jsUndefined, isDenoFile: bool = false): FileIO =
  FileIO(fd: fd, denoFile: denoFile, isDenoFile: isDenoFile, seekable: seekable,
    name: name, writable: writable, append: append)

proc readBuffer*(f: RawIOBase, buf: TypedArray[uint8, auto], pos: int64): cint =
  jsTryAsIOError:
    if f.isDenoFile:
      if f.seekable:
        discard denoSeekSync(f.denoFile, cint(pos), 0)
      result = denoReadSync(f.denoFile, buf)
    else:
      if f.seekable:
        result = fsReadSync(f.fd.cint, buf, 0, buf.length, cint(pos))
      else:
        result = fsReadSync(f.fd.cint, buf, 0, buf.length)

proc writeBuffer*(f: RawIOBase, buf: TypedArray[uint8, auto],
    offset, len: cint, pos: int64): cint =
  jsTryAsIOError:
    if f.isDenoFile:
      if f.seekable and not f.append:
        discard denoSeekSync(f.denoFile, cint(pos), 0)
      result = denoWriteSync(f.denoFile, denoBufSlice(buf, offset))
    else:
      if f.seekable and not f.append:
        result = fsWriteSync(f.fd.cint, buf, offset, len, cint(pos))
      else:
        result = fsWriteSync(f.fd.cint, buf, offset, len)

proc getFileSize*(f: RawIOBase): int64 =
  jsTryAsIOError:
    if f.isDenoFile:
      result = int64(denoSeekSync(f.denoFile, 0, 2))
    else:
      result = int64(jsFstatSize(fsFstatSync(f.fd.cint)))

method flushFile*(f: RawIOBase) {.raises: [].} =
  if f.isDenoFile:
    if f.seekable:
      if f.writable:
        jsTryDiscard:
          denoSync(f.denoFile)
    else:
      jsTryDiscard:
        denoSyncIfSupported(f.denoFile)
    return
  if f.seekable:
    if f.writable:
      jsTryDiscard:
        fsFsyncSync(f.fd.cint)
  else:
    jsTryDiscard:
      fsFsyncSync(f.fd.cint)

method close*(f: RawIOBase) {.raises: [].} =
  if f.fd.cint < 0: return  # never close closed. reentrant
  jsTryDiscard:
    if f.isDenoFile:
      denoClose(f.denoFile)
    else:
      fsCloseSync(f.fd.cint)
  f.fd = FileHandle -1
