## base impl of Python's Lib/warnings
##
## Q: why this exists here?
## A: as warnings.showwarning's `file` param type is `File`,
##   which dep this pkg; while this pkg dep warnings too (in initBufAsPy)

import std/options
import std/strutils

when defined(js):
  import ../jsFile/iobase as nio
else:
  import std/syncio as nio
type File = nio.File

# some simple impl for Python's warnings
type Warning* = enum
  ## PY-DIFF: In CPython it's a class derived from `builtins.Exception`,
  ##  and enums here are subclass of `Warning`
  UserWarning, DeprecationWarning, RuntimeWarning
const DefWarning = UserWarning  ## reprenset the `warning = None` in python. \
  ## as document, it defaults to UserWarning
type
  WarningMessage = tuple
    message: string
    category: Warning
    filename: string
    lineno: int
    file: File
    line: Option[string]

using
  message: string
  category: Warning
  filename: string
  lineno: int

proc formatwarning*(message: string, category: Warning, filename: string, lineno: int;
                   line = none string): string =
  "$#:$#: $#: $#\n" % [filename, $lineno, $category, message]  # can use strformat.fmt

#proc filterwarnings*(action; message="", category=DefWarning, module="", lineno=0, append=false) =

type nFile = nio.File
template decl_showwarning(body): untyped {.dirty.} = 
  bind Warning, WarningMessage, nFile, none
  proc (message: string; category: Warning; filename: string; lineno: int;
            file: nFile = nil; line = none string) =
    body

var showwarning* = decl_showwarning:
  var file = file
  if file.isNil:
    file = nio.stderr
    if file.isNil: return
  file.write formatwarning(message, category, filename, lineno, line)

const noGetFrame = not declared(getFrame)
proc getFrameOf(stacklevel: int): auto =
  when noGetFrame: 0  # placeholder
  else:
    result = getFrame()
    for _ in 1..stacklevel:
      result = result.prev
template warn*(message: string, category: Warning = DefWarning
    , stacklevel=1  #, source = None
  ) = {.line.}:
  bind showwarning
  bind noGetFrame, getFrameOf
  let
    pos = when noGetFrame:
      instantiationInfo(index = stacklevel-2) # XXX: I haven't tried out what the param means, nor doc says
    else:
      getFrameOf(stacklevel)
  let
    lineno = pos.line
    fname = $pos.filename
  showwarning(message, category, fname, lineno)

#[
template catch_warnings*(record=false) =
  ## PY-DIFF:
  ##  - in CPython this is a context manage (of course a class)
  ##  - many other params are supportwd
]#

template catch_warnings_it*(doIt; body) =
  ## EXT.
  bind showwarning, none
  bind WarningMessage
  bind decl_showwarning
  block:
    let old = showwarning
    defer: showwarning = old
    showwarning = decl_showwarning:
      let it{.inject.}: WarningMessage = (message, category, filename, lineno, file, none(string))
      doIt
    body

