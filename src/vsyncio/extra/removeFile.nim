
when defined(js):
  import pkg/jscompat/utils/[dispatch, denoAttrs]
  import pkg/pyerrors/oserr
  proc removeFileRaw(path: cstring) {.
    importByNodeOrDeno(fsModInJs&".unlinkSync", "Deno.removeSync"),
    noconv, raises: [].}
  var removeFileImpl: proc (path: cstring){.noconv, raises: [OSError].}
  template set_removeFileImpl*(prc: typeof(removeFileImpl)) {.dirty.} =
    bind removeFileImpl
    removeFileImpl = prc
  set_removeFileImpl proc (path: cstring){.noconv, raises: [OSError].} =
    catchJsErrAndRaise block:
      removeFileRaw(path)
  proc removeFile(path: string) = removeFileImpl cstring path
else:
  import std/os

export removeFile

when isMainModule:
  removeFile "asdasdsad"

