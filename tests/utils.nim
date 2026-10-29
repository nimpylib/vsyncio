
when defined(js):
  when defined(deno):
    proc removeFile(path: cstring) {.
      importjs: "(()=>{try{Deno.removeSync(#)}catch{}})()".}
  else:
    proc removeFile(path: cstring) {.
      importjs: "(()=>{try{require('node:fs').unlinkSync(#)}catch{}})()".}
    proc removeFile(path: string) = removeFile cstring path
else:
  import std/os

export removeFile

const filename* =
  "tempfiletest"
template writeFileAs*(f; s) {.dirty.} =
  bind filename
  var f = nio.open(filename, fmWrite)
  f.write(s)

