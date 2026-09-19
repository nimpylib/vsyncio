
when defined(js):
  import ../extra/isatty
  import ../jsFile as fileobj_js
  method isatty*(f: fileobj_js.File): bool {.base, raises: [].} =
    isatty(f.fd.int, denoHandle(f), usesDenoFile(f))
else:
  from std/terminal import isatty
  export isatty
