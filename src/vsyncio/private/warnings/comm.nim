
import ./warncls

when defined(js):
  import ../../jsFile/iobase as nio
else:
  import std/syncio as nio
using
  message: string
  category: typedesc[Warning]
  filename: string
  lineno: int
  #action: WarningsFilterAction

