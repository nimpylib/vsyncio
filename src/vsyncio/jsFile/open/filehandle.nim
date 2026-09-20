
import pkg/jscompat/utils/deno
import ../[stdios, bufferedio]
include ./comm

template DenoNoFdHint = discard
# Deno does not allow opening arbitrary file descriptors.

proc open*(f: var File, filehandle: FileHandle,
    mode: FileMode = fmRead): bool =
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
    f = new[BufferedIOBase](name, filehandle, mode)
    return true

