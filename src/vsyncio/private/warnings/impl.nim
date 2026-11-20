
import std/strutils
import std/options
include ./comm
import ./internal_types
using
  category: WarningClass
const None = none string
proc formatwarning*(message: string, category; filename; lineno;
                   line = None): string =
  result = "$#:$#: $#: $#\n" % [filename, $lineno, category.name, message]  # can use strformat.fmt
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

proc formatwarning*(message: ref Warning, category; filename; lineno;
                   line = None): string =
  formatwarning(str(message), category, filename, lineno, line)

template decl_showwarning(body): untyped {.dirty.} = 
  bind WarningMessage
  proc (msg: WarningMessage) = body

#NOTE: in CPython, showwarning is to be assigned,
# but since it's a overloaded function, in a static-typed lang like Nim
#  we cannot make a function both assignable and overloaded
# so we use a new symbol showwarnmsg
var showwarnmsg* = decl_showwarning:
  var file = msg.file
  if file.isNil:
    file = nio.stderr
    if file.isNil: return
  file.write formatwarning(str(msg.message), msg.category, msg.filename, msg.lineno, msg.line)

proc showwarning*(message: string|(ref Warning), category: typedesc[Warning]; filename; lineno; file: File = nil; line = None) =
  template Sor(s, o): untyped =
    when message is string: s else: o
  showwarnmsg(newWarningMessage(
      Sor(message, str(message)),
      category #TODO: Sor(category, realTypeOf(message))
          , filename, lineno, file, line
  ))

const noGetFrame = not declared(getFrame)
proc getFrameOf(stacklevel: int): auto =
  when noGetFrame: 0  # placeholder
  else:
    result = getFrame()
    for _ in 1..stacklevel:
      result = result.prev

template warn*(message: string|(ref Warning), category: typedesc[Warning] = UserWarning
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

