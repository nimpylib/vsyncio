

import ./private/warncls_gen
type
  Warning* = object of CatchableError
    ## In CPython it's a subclass of `builtins.Exception`,

method str*(self: ref Warning): string {.base, raises: [].} =
  ## `__str__`
  self.msg


gens Warning

when isMainModule:
  var v = newException(UserWarning, "")
  echo v of Warning

