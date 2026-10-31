
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

import vsyncio as nio
const filename* =
  "tempfiletest"
template writeFileAs*(f; s) {.dirty.} =
  bind filename
  var f = nio.open(filename, fmWrite)
  f.write(s)

proc readFileCompat*(filename: string): string =
  var ff = nio.open(filename, fmRead)
  result = ff.readAll()
  ff.close()

