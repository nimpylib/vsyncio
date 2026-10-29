## NOTE: syncio.open(...bufSize) discards errors when try setting buffering size.
##
## NOTE: the function signatures here overloads syncio.open,
##   so use **module**.open or `open(...buffering = ..)`
##   to avoid `ambiguous call; both ...`

when defined(js):
  import ../jsFile as fileobj_js
  export open
else:
  import ../extraMeth/m_initBufAsPy
  proc open*(f: var File, p: string, mode: FileMode = fmRead, buffering: int): bool =
    result = f.open(p, mode)
    if result:
      f.initBufAsPy buffering

  proc open*(p: string, mode: FileMode = fmRead, buffering: int): File =
    result = open(p, mode)
    result.initBufAsPy buffering

  proc open*(f: var File, filehandle: FileHandle,
             mode: FileMode = fmRead; buffering: int): bool =
    result = f.open(filehandle, mode)
    if result:
      f.initBufAsPy buffering

