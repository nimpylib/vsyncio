
import vsyncio/extra/removeFile
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

