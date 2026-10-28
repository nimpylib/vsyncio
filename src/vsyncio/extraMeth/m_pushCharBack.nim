

when defined(js):
  import ../jsFile as fileobj_js
  export pushCharBack
else:
  import pkg/pyerrors/oserr
  {.push header: "<stdio.h>".}
  let EOF{.importc.}: cint
  proc c_ungetc(c: cint, f: syncio.File): cint {.
    importc: "ungetc", tags: [].}
  {.pop.}

  proc pushCharBack*(f: syncio.File; c: char) =
    # On error, ungetc returns EOF but doesn't set errno
    let ret = c_ungetc(c.cint, f)
    if ret == EOF:
      raise newException(IOError, "ungetc failed")

