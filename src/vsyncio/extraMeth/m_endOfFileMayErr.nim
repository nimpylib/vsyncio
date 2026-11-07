
import ./private/utils
gen endOfFileMayErr:
  import pkg/errno
  proc endOfFileMayErr*(f: File): bool {.raises: [IOError].} =
    setErrno0()
    result = f.endOfFile()
    let e = getErrno()
    if e != 0:
      #raiseErrno()
      raise newException(IOError, "IOError when endOfFile")

