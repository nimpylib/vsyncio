
when defined(js):
  import ../extra/isatty
  import ../jsFile as fileobj_js
  import ../jsFile/[iobase, rawio]
  export iobase.isatty
  method isatty*(f: RawIOBase): bool =
    let (file, useDeno) = f.getDenoFile
    isatty(getFileHandle(f).int, file, useDeno)
else:
  from std/terminal import isatty
  export isatty
