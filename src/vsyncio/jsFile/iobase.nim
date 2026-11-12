
## Root of the file IO hierarchy, mirroring Python's `io.IOBase`.
import std/macros
import pkg/handy_sugars/assumes
import pkg/jscompat/npointer
import pkg/jscompat/utils/[
  jstypedarrays, jsdataview, jsencodings,
]
import pkg/pyosstat
import ./private/macros
import ../private/[jsbuf, blksize]

type
  FileHandle* = distinct cint
  IOBase* = ref object of RootObj
    closed: bool

using f: IOBase
proc closed*(f): bool = f.closed
proc notImplBaseImpl(exceptions, def: NimNode): NimNode =
  def.addPragma ident"base"
  def.addPragma nnkExprColonExpr.newTree(
    ident"raises",
    exceptions
  )
  def.body = bindSym"unreachable"
  result = def
macro notImplBase(exceptions; def) =
  notImplBaseImpl exceptions, def
macro ionotImplBase(def) =
  notImplBaseImpl parseExpr"[IOError]", def
{.pragma: bIO, base, raises: [IOError].}

{.hint[XCannotRaiseY]: off.}
method initBufAsPy*(f; buf: int) {.base, raises: [IOError, ValueError].} =
  ## EXT.
  unreachable
method pushCharBack*(f; c: char) {.ionotImplBase.} ## \
## EXT. for impl for peekChar
method isatty*(f): bool {.
  notImplBase: [].}  ## EXT. like isatty in std/terminal

method getBlkSize*(f): Blksize {.notImplBase: [OSError].}  ## EXT. like CPython's `f(.raw)._blksize`
method getFileHandle*(f): FileHandle {.notImplBase: [].}

method close*(f) {.base, raises: [].} =
  if f.closed: return
  f.closed = true

method flush*(f) {.ionotImplBase.}  ## EXT. \
  ## however, flushFile has default implementation using this,
  ##   while this method must be implemented.
method flushFile*(f) {.base, raises: [].} =
  try: f.flush()
  except IOError: discard

const PtrCompat = declared(copyMem)

method read*(f; dst: TypedArray[uint8, auto]): int {.ionotImplBase, expBufInArr.}
method write*(f; dst: TypedArray[uint8, auto]): int {.ionotImplBase, expBufInArr.}

template genReadWriteTypedArray*(read, dst, body) {.dirty.} =
  bind expBufInArr
  method read*(f; dst: TypedArray[uint8, auto]): int {.raises: [IOError], expBufInArr.} = body

method readBuffer*(f; buffer: NPointer; len: Natural): int {.bIO.} =
  buffer.asDataViewIt:
    let arr = newUint8Array(it.buffer, it.byteOffset, len.cint)
    result = f.read(arr)

template implReads(pExpr){.dirty.} =
  let len = dst.len
  when PtrCompat:
    let p = dst[0].addr
  else:
    let p = alloc(len)
    defer: dealloc p
  result = f.readBuffer(p, len)
  if result > 0:
    when not PtrCompat:
      for i in 0..<result:
        dst[i] = pExpr

method readChars*(f; dst: var openArray[char]): int {.bIO.} = implReads cast[char](p.getUint8(i))
method readBytes*(f; dst: var openArray[ int8]): int {.bIO.} = implReads p.getInt8 i
method readBytes*(f; dst: var openArray[uint8]): int {.bIO.} = implReads p.getUint8 i

method readChar*(f): char {.bIO.} =
  let p = alloc(1)
  defer: dealloc p
  let n = f.readBuffer(p, 1)
  if n == 0:
    raise new EOFError
  result = cast[char](p.getUint8(0))

method endOfFileMayErr*(f): bool {.bIO.} =
  ## EXT.
  try:
    let c = f.readChar()
    f.pushCharBack(c)
  except EOFError:
    return true
method endOfFile*(f): bool {.base, raises: [].} =
  try:
    result = f.endOfFileMayErr
  except IOError:
    #XXX: Nim's std/syncio ignore endOfFile's IOError
    return true

method readAll*(f): string {.bIO.} =
  const BUF = 8 * 1024
  var buf = newUint8Array(BUF)
  while true:
    let n = f.read(buf)
    if n <= 0: break
    let oldLen = result.len
    result.setLen oldLen + n
    for i in 0..<n:
      result[oldLen + i] = cast[char](buf[i])

method readLine*(f): string {.bIO.} =
  try:
    while true:
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

method write*(f; c: char) {.bIO.} =
  discard f.write newUint8Array([cast[uint8](c)])
method write*(f; s: string) {.bIO.} =
  discard f.write(toUint8Array(s))
method write*(f; s: cstring) {.bIO.} =
  ## uses utf-8 encoding by default
  discard f.write(newTextEncoder().encode(s))

method writeLine*(f; s: string)  {.bIO.} =
  f.write(s)
  f.write("\p")

method writeBuffer*(f; buffer: NPointer; len: Natural): int {.bIO.} =
  buffer.asDataViewIt:
    f.write newUint8Array(it.buffer, it.byteOffset, len.cint)

method getFilePos*(f): int64 {.ionotImplBase.}
method setFilePos*(f; pos: int64,
    rel: FileSeekPos = fspSet) {.ionotImplBase.}
method getFileSize*(f): int64 {.ionotImplBase.}

