
when defined(js):
  import ../jsFile as fileobj_js
  export flush
else:
  import pkg/pyerrors/oserr
  import pkg/errno
  proc flush*(f: syncio.File) {.raises: [IOError].} =
    proc c_fflush(f: syncio.File): cint {.cdecl,
      importc: "fflush", header: "<stdio.h>".}
    let ret = c_fflush(f)
    if ret != 0:
      #XXX: maybe we shall use raiseErrno?
      raise newException(IOError, strerror(getErrno()))

