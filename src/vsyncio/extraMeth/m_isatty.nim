
when defined(js):
  import ../extra/isatty
  import ../jsFile as fileobj_js
  import ../jsFile/bufferedio
  method isatty*(f: fileobj_js.File): bool {.base, raises: [].} =
    isatty(getFileHandle(f).int, denoHandle(f), usesDenoFile(f))
else:
  from std/terminal import isatty
  export isatty
