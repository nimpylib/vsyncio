
import std/hashes
const Js = defined(js)
type
  Class*{.acyclic.} = ref object
    parent: Class  ## `__name__`
    name*: string
    when Js:
      id: int

template jsOr(a, b): untyped =
  when Js: a
  else: b

when not Js:
  template initId(_) = discard
else:
  import std/macros
  import std/macrocache
  const Id = CacheCounter"ClassIdAcc"
  macro initId(Cls) =
    Id.inc
    let id = newLit Id.value
    result = quote do:
      `Cls`.id = `id`

#NOTE: as it's used to declare Exception subclass
# so `Cls` is declared as `object` instead of `ref object`
template declClassAux(Cls, pRT, pragmas) {.dirty.} =
  bind initId
  bind Class
  let `rt Cls` = Class(name: astToStr(Cls), parent: pRT)
  initId `rt Cls`
  converter getClass*(t: typedesc[Cls|ref Cls]): Class = `rt Cls`
  proc getClass*(t: ref Cls): auto = t.`-cls`
  method initRTTI*(result: ref Cls) {.pragmas, raises: [].} =
    ## unstable
    result.`-cls` = `rt Cls`
  proc `new`*(result: var ref Cls) =
    system.new result
    result.initRTTI
  proc `new Cls`*: ref Cls = new result

template declBaseClass*(Cls; Base: untyped = RootObj) =
  bind declClassAux
  bind Class
  type Cls* = object of Base
    `-cls`: Class
  declClassAux(Cls, nil, base)

template noPragma(def) = def
template declClass*(Cls, Base) =
  bind declClassAux, noPragma
  type Cls* = object of Base
  declClassAux(Cls, Base.getClass, noPragma)

when Js:
  proc `==`*(a, b: Class): bool = a.id == b.id
proc `==`*(wc: Class; t: typedesc): bool =
  wc == t.getClass

proc hash*(cls: Class): Hash =
  jsOr(Hash(if cls.isNil: 0 else: cls.id), hash cast[int](cls))

proc issubclass*(x, y: Class): bool =
  var p = x.parent
  while not p.isNil:
    if y == p: return true
    p = p.parent

template issubclass*[T](x, y: ref T): bool =
  bind issubclass
  x.getClass.issubclass y.getClass

