
when defined(js):
  import ./vsyncio/jsFile as fileobj_js
  export fileobj_js except getDenoFile,
         isatty, # not exported to keep consist with std/syncio
         IOBase,
         RawIOBase, FileIO,
         BufferedIOBase, BufferedWriter, BufferedReader,
         BufferedRWPair, BufferedRandom
else:
  import std/syncio
  export syncio

