
## Root of the file IO hierarchy, mirroring Python's `io.IOBase`.

type
  FileHandle* = distinct cint
  IOBase* = ref object of RootObj
