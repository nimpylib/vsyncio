
import pkg/pyosstat
const StatHasBlksize* = compiles(fstat(0).st_blksize)
when StatHasBlksize:
  type Blksize* = typeof(fstat(0).st_blksize)
else:
  type Blksize* = int

proc toIntClamped*(x: Blksize): int =
  when Blksize is int: x
  # Blksize must be signed, as mentioned in posix man
  elif Blksize is SomeFloat or Blksize.sizeof > sizeof(int):
    cast[int](x.clamp(int.low.Blksize, int.high.Blksize))
  else: cast[int](x)

