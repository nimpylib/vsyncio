
import ./[internal_types, impl]
import ./private/locks
#[
template catch_warnings*(record=false) =
  ## PY-DIFF:
  ##  - in CPython this is a context manage (of course a class)
  ##  - many other params are supportwd
]#
template decl_showwarning(body): untyped {.dirty.} = 
  bind WarningMessage
  proc (msg: WarningMessage) = body

template catch_warnings_it*(doIt; body) =
  ## EXT.
  bind showwarnmsg, decl_showwarning
  wmMutLock:
    let old = showwarnmsg
    defer: showwarnmsg = old
    showwarnmsg = decl_showwarning:
      let it{.inject.} = msg
      doIt
    body

