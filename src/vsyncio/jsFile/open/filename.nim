
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

proc open*(f: var File, p: string, mode: FileMode = fmRead): bool =
  if inDeno:
    var denoFile: JsObject
    var failed = false
    var errName: cstring
    jsTryCatchE:
      block:
        denoFile = denoOpenSync(cstring p, denoOpenOpts(mode))
    do:
      failed = true
      {.emit: [errName, " = e.name;"].}
    if failed:
      setErrnoRaw(denoErrno($errName))
      return false
    if denoFile.isNull or denoFile.isUndefined: return false
    f = File(raw: newFileIO(FileHandle -1, seekable = true, name = p,
      writable = mode in {fmWrite, fmAppend, fmReadWriteExisting, fmReadWrite},
      append = mode == fmAppend,
      denoFile = denoFile, isDenoFile = true))
    return true
  var fd: cint = -1
  catchJsErrAndSetErrno:
    fd = fsOpenSync(cstring p, jsPrivOpenFlags[mode])
  if fd < 0: return false
  f = File(raw: newFileIO(FileHandle fd, seekable = true, name = p,
    writable = mode in {fmWrite, fmAppend, fmReadWriteExisting, fmReadWrite},
    append = mode == fmAppend))
  result = true

proc open*(filename: string,
            mode: FileMode = fmRead): File =
  if not open(result, filename, mode):
    raise newException(IOError, "cannot open: " & filename)
