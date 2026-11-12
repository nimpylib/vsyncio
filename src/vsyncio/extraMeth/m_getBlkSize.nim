
import ./private/utils
import ../private/blksize
export toIntClamped
genBase getBlkSize:
  import pkg/pyosstat/stat
  when not StatHasBlksize:
    import ../private/consts
  proc getBlkSize*(f: syncio.File): Blksize {.raises: [OSError].} =
    ## CPython: raw._blksize
    when StatHasBlksize:
      statAttr(f.getFileHandle().int, st_blksize)
    else:
      DEFAULT_BUFFER_SIZE
