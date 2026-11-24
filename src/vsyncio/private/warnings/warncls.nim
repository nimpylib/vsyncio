

import ./private/[rtti_gen, warncls_gen]
export rtti_gen except declClass, declBaseClass

declBaseClass Warning, CatchableError
## In CPython it's a subclass of `builtins.Exception`,

proc newException*[W: Warning](w: typedesc[W]; msg: string): ref Warning =
  result = system.newException(w, msg)
  result.initRTTI

using self: ref Warning
method str*(self): string {.base, raises: [].} =
  ## `__str__`
  self.msg

proc repr*(self): string =
  result = $self.getClass.name
  result.add '('
  result.add self.str.pyrepr
  result.add ')'

gens Warning, declClass

when isMainModule:
  var v = newException(UserWarning, "s")
  #var v = newUserWarning()

  assert v of Warning
  assert v.getClass != newException(DeprecationWarning, "s").getClass

