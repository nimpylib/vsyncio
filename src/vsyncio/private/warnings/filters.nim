import std/tables
import std/lists
import std/strutils
import std/options
import pkg/pyre
include ./comm
import ./internal_types
import ./private/locks

type
  WarningsFilterAction* = enum
    ## EXT. PY-DIFF: In CPython, it's reprensented as a `str`
    default, error, ignore, always, all, module, once
const defaultaction = WarningsFilterAction.default
using
  action: string|WarningsFilterAction
  message: Regex
  module: Regex
converter toAction*(s: string): WarningsFilterAction =
  parseEnum[WarningsFilterAction](s)

let emptyre = none Regex

#NOTE: we store a new-ed object just to access its inherit-table
# as in Nim there is no official `type` object (`typedesc` is static info)
# Note this works because the category is just used to check `issubclass`
type FilterItem = (WarningsFilterAction, Option[Regex], ref Warning, Option[Regex], int)
var filters: DoublyLinkedList[FilterItem]
var onceregistry: Table[(string, WarningClass), int]

iterator get_filters: FilterItem =
  for i in filters.items: yield i

proc filterwarnings*(action; message=emptyre, category: typedesc[Warning] = Warning, module=emptyre, lineno=0, append=false) =
  if lineno < 0:
    raise newException(ValueError, "lineno must be an int >= 0")
  let it = (action, message, new category, module, lineno)
  wmMutLock:
    if append: filters.preappend it
    else: filters.append it
proc simplefilter*(action; category: typedesc[Warning] = Warning, lineno=0, append=false) =
  filterwarnings(action, emptyre, category, emptyre, lineno, append)

proc resetwarnings* =
  wmMutLock:
    filters = default typeof filters

proc match_filename(pattern: Regex, filename: string): bool =
  if filename == "":
    return pattern.match("<unknown>").isSome
  if filename[0] == '<' and filename[^1] == '>':
    return pattern.match(filename).isSome

  # is_py in CPython
  const suf = ".nim"
  let is_nim = filename.endswith(suf)
  var filename = if is_nim:
    filename[0 ..< ^suf.len]
  else: filename
  if pattern.match(filename).isSome:  # for backward compatibility
    return true
  when false:
    # cpython has to removesuffix __init__; we nim need not
    if MS_WINDOWS: `...`
    else:
      if is_py and filename.endswith("/__init__"):
          filename = filename[0..<^9]
  filename = filename.replace('/', '.')
  var i = 0
  while true:
    if pattern.match(filename, i).isSome:
      return true
    i = filename.find('.', i) + 1
    if i == 0: # -1 + 1 -> not found
      return false

const None = none string
proc getDefRegistry*: auto =
  newTable[(string, WarningClass, int), int]()
proc do_filters*(message: ref Warning; text: string, category;
    filename; lineno;
    module=None, registry=getDefRegistry(),
    module_globals=None,
    ): bool {.raises: [Warning].} =
  bind hash
  result = false
  let Scategory = category.getClass
  let key = (text, Scategory, lineno)
  wmLock:
    assert registry.isNil.not  # Python uses None
    #  as it cannot directly use defval for containers like dict
    let version = ("version", WarningClass.default, 0)
    if registry.getOrDefault(version, 0) != filters_version:
      registry.clear()
      registry[version] = filters_version
    # Quick test for common case
    if key in registry:
      return
    # Search the filters
    var
      action: WarningsFilterAction
    block toLookFor:
      for item in get_filters():
        let (act, msg, cat, modu, ln) = item
        static:assert cat is ref Warning  # see above. not class but obj
        try:
          if ((msg.isNone or msg.unsafeGet.match(text).isSome) and
            issubclass(category.getClass, cat.getClass) and
            (ln == 0 or lineno == ln) and
            (modu.isNone or (
              let modul = modu.unsafeGet
              if module.isNone: match_filename(modul, filename)
              else: modul.match(module.unsafeGet).isSome
            ))
          ):
            action = act
            break toLookFor
        except PatternError as e:
          #TODO:respect `e`
          continue
      # if not found
      action = defaultaction
    case action
    of ignore:
      # Early exit actions
      return
    of error:
      raise message
    # Other actions
    of once:
      registry[key] = 1
      let oncekey = (text, Scategory)
      if onceregistry.hasKeyOrPut(oncekey, 1):
        return
    of always, all:
      discard
    of WarningsFilterAction.module:
      registry[key] = 1
      let altkey = (text, Scategory, 0)
      if registry.hasKeyOrPut(altkey, 1):
        return
    of default:
      registry[key] = 1
    #[ unreachable
    else:
      # Unrecognized actions are errors
      raise newException(RuntimeError,
            "Unrecognized action ('$#') in warnings.filters:\n $#" %
            [action, item])
    ]#
    return not result

