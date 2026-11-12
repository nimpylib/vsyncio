
import ../private/consts
when defined(js):
  import ../jsFile/iobase
  type File = IOBase
else:
  import std/syncio
import ../extraMeth/[m_getBlkSize, m_isatty]

proc norm_buffering*(file: File, buffering: var int): bool {.discardable.} =
  ## returns line_buffering
  ##
  ## after calling, `buffering` will never be negative
  var line_buffering = false
  if buffering == 1 or buffering < 0 and file.isatty():
    buffering = -1
    line_buffering = true
  if buffering < 0:
    buffering = try:
      let bs = file.getBlkSize.toIntClamped  # `os.fstat(raw.fileno()).st_blksize`, but supports js
      # C: max(min(bs, 8192 * 1024), DEFAULT_BUFFER_SIZE)
      bs.clamp(DEFAULT_BUFFER_SIZE, 8192 * 1024)
    except OSError:
      DEFAULT_BUFFER_SIZE
  if buffering < 0: raise newException(ValueError, "invalid buffering size")
  result = line_buffering

