
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

