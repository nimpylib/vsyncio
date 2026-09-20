
## Root of the file IO hierarchy, mirroring Python's `io.IOBase`.
import std/macros
import pkg/handy_sugars/assumes

type
  FileHandle* = distinct cint
  IOBase* = ref object of RootObj

using f: IOBase
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

{.hint[XCannotRaiseY]: off.}
method pushCharBack*(f; c: char) {.notImplBase: [].} ## \
## EXT. for impl for peekChar
method isatty*(f): bool {.
  notImplBase: [].}  ## EXT. like isatty in std/terminal
method getFileHandle*(f): FileHandle {.notImplBase: [].}
method flushFile*(f) {.notImplBase: [].}
method close*(f) {.notImplBase: [].}

method readChar*(f): char {.ionotImplBase.}
method readAll*(f): string {.ionotImplBase.}
method readLine*(f): string {.ionotImplBase.}


method write*(f; c: char) {.ionotImplBase.}
method write*(f; s: string) {.ionotImplBase.}
method write*(f; s: cstring) {.ionotImplBase.}

method writeLine*(f; s: string) {.ionotImplBase.}

method getFilePos*(f): int64 {.ionotImplBase.}
method setFilePos*(f; pos: int64,
    rel: FileSeekPos = fspSet) {.ionotImplBase.}

