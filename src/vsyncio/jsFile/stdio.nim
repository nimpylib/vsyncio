
import std/jsconsole
import pkg/handy_sugars/assumes
import ./bufferedio
export bufferedio.FileHandle
type
  StdioFile* = ref object of BufferedIOBase

method writeLine*(f: StdioFile, s: string) =
  case getFileHandle(f).cint
  of 1:
    console.log(cstring s)
  of 2:
    console.error(cstring s)
  of 0:
    raise newException(IOError, "standard input is not writable")
  else:
    unreachable

