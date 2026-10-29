
import pkg/jscompat/utils/deno
import ../[stdios, bufferedio, rawio]
include ./comm

template DenoNoFdHint = discard
# Deno does not allow opening arbitrary file descriptors.

proc open*(f: var File, filehandle: FileHandle,
    mode: FileMode = fmRead; buffering = -1): bool =
  let fd = filehandle.cint
  if fd < 0: return false
  template retf(tf) =
    f = tf
    return true
  case fd
  of 0: retf stdin
  of 1: retf stdout
  of 2: retf stderr
  else: discard
  if inDeno:
    DenoNoFdHint
    return false
  else:
    let name = "<fd " & $fd & ">"
    if buffering == 0:
      f = newFileIO(filehandle, name, mode, seekable = true) #TODO:seekable
    else:
      f = new[BufferedIOBase](name, filehandle, mode)
      f.initBufAsPy buffering
    return true

