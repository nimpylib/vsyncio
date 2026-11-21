## internal.
import ./m_initBufAsPy
import ../private/[getPrefBufSize]
import ./private/utils
genBase File:
  import std/syncio as nio
proc initBufAsPyInternal*(nfile: nio.File, buf: int) =
  var buf = buf
  norm_buffering_for_binary(nfile, buf, 2)
  initBufAsPy(nfile, buf)

