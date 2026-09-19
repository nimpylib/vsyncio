
when defined(js):
  import ./vsyncio/jsFile as fileobj_js
  export fileobj_js except denoHandle, usesDenoFile
else:
  import std/syncio
  export syncio

