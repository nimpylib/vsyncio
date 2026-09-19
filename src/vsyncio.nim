
when defined(js):
  import ./vsyncio/jsFile as fileobj_js
  export fileobj_js except denoHandle, usesDenoFile,
         RawIOBase, FileIO,
         BufferedIOBase, BufferedWriter, BufferedReader,
         BufferedRWPair, BufferedRandom
else:
  import std/syncio
  export syncio

