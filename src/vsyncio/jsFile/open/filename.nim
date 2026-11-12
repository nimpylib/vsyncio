
import std/jsffi
import pkg/jscompat/utils/[dispatch, deno]
import pkg/pyerrors/oserr
import pkg/errno/errnoUtils
import ../../private/jsutils
import ../[rawio, bufferedio]
import ../private/helpers
include ./comm

# NOTE: `catchJsErrAndRaise` and `catchJsErrAndSetErrno` used below
# come from `pkg/pyerrors/oserr` (imported by pyio_open.nim)


const jsPrivOpenFlags: array[FileMode, cstring] = [
  cstring"r", cstring"w", cstring"w+", cstring"r+", cstring"a"
]

proc open*(f: var File, p: string, mode: FileMode = fmRead, buffering = -1): bool =
  var raw: RawIOBase
  if inDeno:
    var denoFile: JsObject = jsNull
    var failed = false
    var errCode: cstring
    catchJsErrAndSetErrno:
      denoFile = denoOpenSync(cstring p, denoOpenOpts(mode))
    if denoFile.isNull: return false
    raw = newDenoFileIO(denoFile, p, mode)
  else:
    var fd: cint = -1
    catchJsErrAndSetErrno:
      fd = fsOpenSync(cstring p, jsPrivOpenFlags[mode])
    if fd < 0: return false
    raw = newFileIO(FileHandle fd, p, mode)
  if buffering == 0:
    f = raw
  else:
    f = new[BufferedIOBase](raw)
    f.initBufAsPy buffering
  result = true

proc open*(filename: string,
            mode: FileMode = fmRead, buffering = -1): File =
  if not open(result, filename, mode, buffering):
    raise newException(IOError, "cannot open: " & filename)
