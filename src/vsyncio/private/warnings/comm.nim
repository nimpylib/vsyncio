
import ./warncls

when defined(js):
  import ../../jsFile/iobase as nio
else:
  import std/syncio as nio
type File = nio.File
using
  message: string
  category: typedesc[Warning]
  filename: string
  lineno: int
  #action: WarningsFilterAction

