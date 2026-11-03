when defined(js):
  import pkg/jscompat/utils/dispatch
  proc cIsatty(fd: cint): bool {.importc: ttyOrDenoInJs & ".isatty".}
  proc denoStdinIsatty(): bool {.importjs: "Deno.stdin.isTerminal(@)".}
  proc denoStdoutIsatty(): bool {.importjs: "Deno.stdout.isTerminal(@)".}
  proc denoStderrIsatty(): bool {.importjs: "Deno.stderr.isTerminal(@)".}
  proc isatty*(fd: int): bool =
    if not notDeno:
      case fd
      of 0: return denoStdinIsatty()
      of 1: return denoStdoutIsatty()
      of 2: return denoStderrIsatty()
      else: discard
    cIsatty(fd.cint)

else:
  when defined(windows):
    proc c_isatty(fildes: cint): cint {.
      importc: "_isatty", header: "<io.h>".}
  elif defined(posix) or defined(bsd):
    proc c_isatty(fildes: cint): cint {.
      importc: "isatty", header: "<unistd.h>".}

  func isatty*(fd: int): bool =
    c_isatty(fd.cint) != 0

