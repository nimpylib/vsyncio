
when defined(js):
  import ../jsFile as fileobj_js
  export initBufAsPy
else:
  import pkg/handy_sugars/assumes

  {.push header: "<stdio.h>".}
  proc c_setvbuf(f: syncio.File, buf: pointer, mode: cint, size: csize_t): cint {.
    importc: "setvbuf".}
  let
    IOFBF {.importc: "_IOFBF".}: cint
    IOLBF {.importc: "_IOLBF".}: cint
    # NOTE: For Win32, the behavior is the same as _IOFBF - Full Buffering
    IONBF {.importc: "_IONBF".}: cint
  {.pop.}

  proc initBufAsPy*(nfile: syncio.File, buf: int) =
    ## init buffering as Python's
    var (bfMode, bfSize) =
      if buf == 1: (IOLBF, 0)
      elif buf > 0 and buf.uint <= high(uint):
        (IOFBF, buf)
      elif buf == 0:
        (IONBF, 0)
      else: unreachable
    let ret = c_setvbuf(nfile, nil, bfMode, cast[csize_t](bfSize))
    if ret != 0:
      raise newException(IOError, "setvbuf failed")

