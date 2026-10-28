
when defined(js):
  import ../jsFile as fileobj_js
  export initBufAsPy
else:
  import pkg/handy_sugars/assumes
  import pkg/errno

  {.push header: "<stdio.h>".}
  proc c_setvbuf(f: syncio.File, buf: pointer, mode: cint, size: csize_t): cint {.
    importc: "setvbuf".}
  let
    IOFBF {.importc: "_IOFBF".}: cint
    IOLBF {.importc: "_IOLBF".}: cint
    IONBF {.importc: "_IONBF".}: cint
  {.pop.}

  proc initBufAsPy*(nfile: syncio.File, buf: int) =
    ## init buffering as Python's.
    ##  NOTE: `buf` == 1 doesn't mean Line-Buffering,
    ##    as this is not of TextIOBase, but RawIOBase,
    ##      which lacks meaning of `line_buffering`
    if buf < 0:
      # Nim std/syncio has set default bufSize on open
      return
    let (bfMode, bfSize) =
      case buf
      #of 1: (IOLBF, 0)  # see NOTE above
      of 0: (IONBF, 0)
      else:
        (IOFBF, buf)
    setErrno0()
    let ret = c_setvbuf(nfile, nil, bfMode, cast[csize_t](bfSize))
    if ret != 0:
      if isErr EINVAL:
        # e.g. windows only allows range: 2 <= size <= INT_MAX
        proc c_strerror(e: cint): cstring {.importc: "strerror", header: "<errno.h>".}
        raise newException(ValueError, $c_strerror(EINVAL))
      elif isErr EBADF:
        # POSIX indiates such errno
        raise newException(ValueError, "I/O operation on closed file.")
      raise newException(IOError, "setvbuf failed")

