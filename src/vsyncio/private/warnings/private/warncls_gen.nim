
import std/macros

type
  BltinWarning{.pure.} = enum
    ## PY-DIFF: In CPython it's a class derived from `builtins.Exception`,
    ##  and enums here are subclass of `Warning`
    UserWarning DeprecationWarning PendingDeprecationWarning
    SyntaxWarning RuntimeWarning FutureWarning
    ImportWarning
    UnicodeWarning BytesWarning EncodingWarning
    ResourceWarning
macro gens*(Base: typedesc; declClass) =
  result = newStmtList()
  for i in BltinWarning:
    let id = ident $i
    result.add quote do:
      `declClass` `id`, `Base`

