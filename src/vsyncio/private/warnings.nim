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
type
  BltinWarning* = enum
    ## PY-DIFF: In CPython it's a class derived from `builtins.Exception`,
    ##  and enums here are subclass of `Warning`
    UserWarning DeprecationWarning PendingDeprecationWarning
    SyntaxWarning RuntimeWarning FutureWarning
    ImportWarning
    UnicodeWarning BytesWarning EncodingWarning
    ResourceWarning

const DefWarning = UserWarning  ## reprenset the `warning = None` in python. \
  ## as document, it defaults to UserWarning
type
  WarningMessage = tuple
    message: string
    category: BltinWarning
    filename: string
    lineno: int
    file: File
    line: Option[string]

using
  message: string
  category: BltinWarning
  filename: string
  lineno: int

const None = none string
proc formatwarning*(message: string, category; filename; lineno;
                   line = None): string =
  result = "$#:$#: $#: $#\n" % [filename, $lineno, $category, message]  # can use strformat.fmt
  template addSource(line) =
    result.add "  "
    result.add line
    result.add '\n'

  if line.isNone:
   #TODO:getline
   when declared(getLine):
    var f: nio.File
    let succ = f.open(filename, fmRead)
    if succ:
      defer: f.close
      let l = try: f.getLine(lineno)
      except IOError: return
      addSource l
  else:
    addSource line.unsafeGet

#proc filterwarnings*(action; message="", category=DefWarning, module="", lineno=0, append=false) =

type nFile = nio.File
template decl_showwarning(body): untyped {.dirty.} = 
  bind BltinWarning, WarningMessage, nFile, None
  proc (message: string; category: BltinWarning; filename: string; lineno: int;
            file: nFile = nil; line = None) =
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
template warn*(message: string, category: BltinWarning = DefWarning
    , stacklevel=1, source = None
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
  showwarning(message, category, fname, lineno, nil, source)

#[
template catch_warnings*(record=false) =
  ## PY-DIFF:
  ##  - in CPython this is a context manage (of course a class)
  ##  - many other params are supportwd
]#

template catch_warnings_it*(doIt; body) =
  ## EXT.
  bind showwarning
  bind WarningMessage
  bind decl_showwarning, None
  block:
    let old = showwarning
    defer: showwarning = old
    showwarning = decl_showwarning:
      let it{.inject.}: WarningMessage = (message, category, filename, lineno, file, None)
      doIt
    body

