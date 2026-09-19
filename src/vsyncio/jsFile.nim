## JS target only (Node.js/Deno)
## 
## it re-declares `File`/`FileHandle` and implements file IO
## on top of `node:fs` or Deno's synchronous FsFile API,
## modeled after `std/syncio`.

import pkg/handy_sugars/trans_imp

impExpCwd jsFile, [
  rawio, bufferedio, stdios, openfile,
]

