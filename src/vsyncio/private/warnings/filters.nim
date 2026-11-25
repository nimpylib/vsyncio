## placeholder for warning filters; real implementation is in nimpylib/pywarnings
import std/tables
import std/options
include ./comm
import ./internal_types
export nio

const None = none string
proc getDefRegistry*: auto =
  newTable[(string, WarningClass, int), int]()

var do_filters*: proc (message: ref Warning; text: string, category: WarningClass;
      filename: string; lineno: int;
      module=None, registry=getDefRegistry(),
      module_globals=None,
      ): bool {.raises: [Warning].}

template decl_do_filters*(body) {.dirty.} =
  bind do_filters
  bind Warning, WarningClass, None, getDefRegistry
  do_filters = proc (message: ref Warning; text: string, category: WarningClass;
       filename: string; lineno: int;
      module=None, registry=getDefRegistry(),
      module_globals=None,
      ): bool {.raises: [Warning].} =
    body

{.hint[XCannotRaiseY]: off.}
decl_do_filters:
  return true

