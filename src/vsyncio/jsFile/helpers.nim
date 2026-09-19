
import std/jsffi

import pkg/jscompat/utils/oserr
import pkg/jscompat/utils/dispatch

proc jsFstatSize*(o: JsObject): cint {.importjs: "#.size".}

proc fsOpenSync*(path: cstring, flags: cstring): cint {.importjs: fs"openSync".}
proc fsCloseSync*(fd: cint) {.importjs: fs"closeSync".}
# NOTE: `pos` must be a JS `number` (not a BigInt) for node's `fs`
proc fsReadSync*(fd: cint, buf: JsObject, offset: cint, len: cint, pos: cint | JsObject = jsUndefined): cint {.
  importjs: fs"readSync".}
proc fsWriteSync*(fd: cint, buf: JsObject, offset: cint, len: cint, pos: cint | JsObject = jsUndefined): cint {.
  importjs: fs"writeSync".}
proc fsFstatSync*(fd: cint): JsObject {.importjs: fs"fstatSync".}
proc fsFsyncSync*(fd: cint) {.importjs: fs"fsyncSync".}

proc denoOpenSync*(path: cstring, opts: JsObject): JsObject {.
  importjs: "Deno.openSync(#, #)".}
proc denoClose*(f: JsObject) {.importjs: "#.close()".}
proc denoReadSync*(f, buf: JsObject): cint {.importjs: "(#.readSync(#) ?? 0)".}
proc denoWriteSync*(f, buf: JsObject): cint {.importjs: "#.writeSync(#)".}
proc denoBufSlice*(buf: JsObject, start: cint): JsObject {.importjs: "#.subarray(#)".}
proc denoSeekSync*(f: JsObject, pos: cint, whence: cint): cint {.
  importjs: "#.seekSync(#, #)".}
proc denoSync*(f: JsObject) {.importjs: "#.syncSync()".}
proc denoSyncIfSupported*(f: JsObject) {.importjs: "#.syncSync?.()".}

template jsExpr*(x: string): JsObject =
  var temp: JsObject
  {.emit: [temp, " = " & x].}
  temp

proc denoOpenOpts*(mode: FileMode): JsObject =
  case mode
  of fmRead: jsExpr"({read: true})"
  of fmWrite: jsExpr"({write: true, create: true, truncate: true})"
  of fmReadWrite: jsExpr"({read: true, write: true, create: true, truncate: true})"
  of fmReadWriteExisting: jsExpr"({read: true, write: true})"
  of fmAppend: jsExpr"({write: true, create: true, append: true})"

proc denoErrno*(name: string): cint =
  case name
  of "NotFound": ErrNoent.cint
  of "AlreadyExists": ErrExist.cint
  of "IsADirectory": ErrIsdir.cint
  else: 0

