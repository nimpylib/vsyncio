## Raw (unbuffered) binary IO, mirroring Python's `io.RawIOBase` and `io.FileIO`.
##
## `FileIO` is the concrete raw file. A `seekable` file does positioned
## reads/writes (so the buffered layer can track the position itself); the
## standard streams are non-seekable and are read/written sequentially.

import std/jsffi

import pkg/handy_sugars/assumes
import pkg/jscompat/utils/[jstypedarrays, jsarraybuffer, ]

import ../private/[jsutils, consts]
import ./private/helpers
import ./iobase

type FileHandle = iobase.FileHandle  # shadow system's syncio.FileHandle

type
  RawIOBase* = ref object of IOBase
    writable*: bool

  FileIO* = ref object of RawIOBase
    name*: string
    fd*: FileHandle
    filePos: int64  ## used for getFilePos and after setFilePos
    # XXX: tho Deno.File has seek[Sync], it lacks tell (
    #   NOTE: `seek(0, 1)` will error on unseekable so cannot be used)
    posIsSet: bool
  NodeFileIO = ref object of FileIO
  DenoFileIO = ref object of FileIO
    denoFile: JsObject

method getFileHandle*(f: FileIO): FileHandle {.raises: [].} = f.fd
method getDenoFile*(f: RawIOBase): tuple[f: JsObject, useDeno: bool] {.base, raises: [].} =
  (jsUndefined, false)
method getDenoFile*(f: DenoFileIO): tuple[f: JsObject, useDeno: bool] {.raises: [].} =
  (f.denoFile, true)

method initBufAsPy*(f: RawIOBase; buf: int) =
  raise newException(ValueError, "cannot setbuf for raw IO")
method pushCharBack*(f: RawIOBase; c: char) =
  raise newException(IOError, "cannot ungetc for raw IO on JS backend")

proc newFileIO*(fd: FileHandle, name: string, mode: FileMode,
    ): FileIO =
  ## For NodeJs backend. As Deno doesn't has file handle API since v2
  let append = mode == fmAppend
  result = NodeFileIO(fd: fd, name: name,
    writable: mode != fmRead)
  if append:
    result.filePos = result.getFileSize()

proc newDenoFileIO*(denoFile: JsObject,
    name: string, mode: FileMode,
    fd = FileHandle(-1)): FileIO =
  let append = mode == fmAppend
  result = DenoFileIO(fd: fd, denoFile: denoFile,
    name: name,
    writable: mode != fmRead)
  if append:
    result.filePos = result.getFileSize()

using f: FileIO
method setFilePos*(f; pos: int64,
    rel: FileSeekPos = fspSet) {.raises: [IOError].} =
  f.posIsSet = true
  case rel
  of fspSet:
    f.filePos = pos
  of fspCur:
    f.filePos += pos
  of fspEnd:
    f.filePos = f.getFileSize() + pos

method getFilePos*(f): int64 {.raises: [].} = f.filePos

# and shared Uint8Array buffers.
method pread*(f: FileIO, buf: JsObject, pos: int64): cint {.base, raises: [IOError].} =
  ## XXX: the file pos won't be updated
  unreachable

method setFilePos*(f: DenoFileIO; pos: int64,
    rel: FileSeekPos = fspSet) =
  procCall setFilePos(FileIO(f), pos, rel)
  jsTryAsIOError:
    discard denoSeekSync(f.denoFile, pos, rel.ord.cint)

method endOfFileMayErr*(f): bool =
  f.getFilePos() == f.getFileSize()

#[
TSV Table: Reasons why `A single read() or write() may return shorter number than required`

Cause	Typical FD type	What happens	Return value
End of file reached	Regular file	Fewer bytes remain than requested	> 0 short count; 0 means EOF
Signal interruption	Any	Signal delivered mid-transfer	-1 + EINTR (no bytes yet), or short count if some bytes moved opengroup.org
Internal buffer limit	Pipe / FIFO / tty	Only what fits in the pipe buffer (typically 64 KB on Linux) or one line of terminal input is available github.com	Short count
Data not yet available	Socket, pipe	Only the bytes currently in the kernel buffer are returned ibm.com	Short count
Non-blocking, would block	Any with O_NONBLOCK	No data ready to move	-1 + EAGAIN/EWOULDBLOCK die.net
Kernel size cap	Any (Linux)	write() transfers at most 0x7ffff000 ≈ 2 GB per call man7.org	Short count
Direct I/O partial failure	Regular file (O_DIRECT)	Error may occur mid-transfer	Short count; file offset considered inconsistent man7.org
]#

template ioDoRes(body) =
  jsTryAsIOError:
    result = int body
  f.filePos.inc result

type Buf = TypedArray[uint8, SharedArrayBuffer] | TypedArray[uint8, ArrayBuffer]
method read*(f: RawIOBase, buf: Buf; offset, len: int): int {.base, raises: [IOError].} = unreachable
method read*(f: RawIOBase, buf: Buf): int {.raises: [IOError].} = f.read(buf, 0, buf.len)

method write*(f: RawIOBase, buf: Buf; offset, len: int): int {.base, raises: [IOError].} = unreachable
method write*(f: RawIOBase, buf: Buf): int {.raises: [IOError].} = f.write(buf, 0, buf.len)

proc posParam(f: NodeFileIO; bigInt: static[bool] = true): JsObject =
  # NOTE: node's `fs` requires a JS `number` here.
  #   As writeSync doesn't accept BigInt (while readSync does)
  if f.posIsSet:
    when bigInt: f.filePos.toJs
    else: cint(f.filePos).toJs
  else: jsNull
method read*(f: NodeFileIO, buf: Buf; offset, len: int): int =
  ioDoRes fsReadSync(f.fd.cint, buf, offset, len, f.posParam)
method read*(f: DenoFileIO, buf: Buf; offset, len: int): int =
  ioDoRes denoReadSync(f.denoFile, buf.subarray(offset, offset+len))

method write*(f: NodeFileIO, buf: Buf; offset, len: int): int =
  ioDoRes fsWriteSync(f.fd.cint, buf, offset, len, f.posParam(false))
method write*(f: DenoFileIO, buf: Buf; offset, len: int): int =
  ioDoRes denoWriteSync(f.denoFile, buf.subarray(offset, offset+len))

method pread*(f: NodeFileIO, buf: Buf; pos: int64): cint =
  jsTryAsIOError:
    let len = buf.length.to(cint)
    result = fsReadSync(f.fd.cint, buf, 0, len, cint(pos))

method pread*(f: DenoFileIO, buf: Buf; pos: int64): cint =
  jsTryAsIOError:
    discard denoSeekSync(f.denoFile, cint(pos), 0)
    result = denoReadSync(f.denoFile, buf)
    discard denoSeekSync(f.denoFile, f.filePos, 0)

method pwrite*(f: RawIOBase, buf: Buf;
    offset, len: cint, pos: int64): cint {.base, raises: [IOError].} =
  unreachable

method pwrite*(f: NodeFileIO, buf: Buf;
    offset, len: cint, pos: int64): cint =
  jsTryAsIOError:
    result = fsWriteSync(f.fd.cint, buf, offset, len, cint(pos))

method pwrite*(f: DenoFileIO, buf: Buf; offset, len: cint, pos: int64): cint =
  jsTryAsIOError:
    discard denoSeekSync(f.denoFile, cint(pos), 0)
    result = denoWriteSync(f.denoFile,
      buf.subarray(offset, offset + len))
    discard denoSeekSync(f.denoFile, f.filePos, 0)

method getFileSize*(f: NodeFileIO): int64 =
  jsTryAsIOError:
    result = int64(jsFstatSize(fsFstatSync(f.fd.cint)))

method getFileSize*(f: DenoFileIO): int64 =
  jsTryAsIOError:
    result = int64(denoSeekSync(f.denoFile, 0, 2))
    discard denoSeekSync(f.denoFile, f.filePos, fspSet.ord.cint)

template flushImpl =
  if f.closed:
    raise newException(IOError, ioOnClosedErrMsg)
template genFlush(flushFile) {.dirty.} =
  method flushFile*(f: NodeFileIO) =
    flushImpl

  method flushFile*(f: DenoFileIO) =
    flushImpl
genFlush flush

method close*(f: NodeFileIO) {.raises: [].} =
  # we shall not set f.fd to -1 as we need
  #   node to raise error with EBADF errno when acting on closed file
  # otherwise, a
  #   `RangeError: The value of "fd" is out of range. It must be >= 0 && <= 2147483647. Received -1`
  #   will be thrown
  procCall(RawIOBase(f).close())
  fsCloseSync(f.fd.cint)

method close*(f: DenoFileIO) {.raises: [].} =
  # we shall not set f.denoFile to jsUndefined as we need
  #   with the same reason above.
  procCall(RawIOBase(f).close())
  denoClose(f.denoFile)

