
import std/[jsconsole, strutils]
import pkg/handy_sugars/assumes
import pkg/jscompat/utils/dispatch
import ../private/jsutils
import ./bufferedio
export bufferedio.FileHandle

type
  StdioFile* = ref object of BufferedIOBase
    lineBuf: string

method flush*(f: StdioFile) =
  #TODO:flush
  discard  # currently rawio.flush uses fsync
  # which cannot perform on stdio
method initBufAsPy*(f: StdioFile; buf: int) =
  raise newException(ValueError, "setbuf for StdioFile not impl")

template impProcessStdio(R, stdout, write) {.dirty.} =
  proc `process stdout write`(s: cstring): R {.importjs:
    "process." & astToStr(stdout) & '.' & astToStr(write) & "(#)".}
impProcessStdio void, stdout, write
impProcessStdio void, stderr, write

template processOr(ifDo, elseDo) =
  when defined(nodejs): ifDo
  else:
    if notHasProcess: elseDo
    else: ifDo

proc bufferedWrite(f: StdioFile, s: string|cstring) =
  ## cache until a '\n' appears, then flush each complete line via `writeLine`
  f.lineBuf.add s
  var i = 0
  while true:
    let nl = f.lineBuf.find('\n', i)
    if nl < 0: break
    f.writeLine(f.lineBuf[i ..< nl])
    i = nl + 1
  if i > 0:
    if i < f.lineBuf.len:
      f.lineBuf = f.lineBuf[i .. ^1]
    else:
      f.lineBuf.setLen 0

template stdoutOrStderr(f, outDo, errDo) =
  case getFileHandle(f).cint
  of 1:
    jsTryAsIOError: outDo
  of 2:
    jsTryAsIOError: errDo
  of 0: raise newException(IOError, "standard input is not writable")
  else: unreachable

{.push raises: [IOError].}
method write*(f: StdioFile, s: cstring) =
  processOr:
    f.stdoutOrStderr(
      processStdoutWrite(s),
      processStderrWrite(s)
    )
  do: bufferedWrite(f, s)

method write*(f: StdioFile, s: string) =
  f.write cstring s

method write*(f: StdioFile, c: char) =
  proc cstringFromCharOrd(c: int): cstring {.
    importjs: "String.fromCharCode(#)", raises: [].}
  f.write cstringFromCharOrd c.ord

method writeLine*(f: StdioFile, s: string) =
  f.stdoutOrStderr(
    console.log(cstring s),
    console.error(cstring s)
  )
{.pop.}

