
import ./warncls
proc getClassName(t: typedesc[Warning]): string =
  #XXX: this shall be dynamic; but currently hard to impl.
  # Currently only use its superficial type name (static)
  $t

type
  WarningClass* = object
    name*: string  ## `__name__`

proc `==`*(wc: WarningClass; t: typedesc[Warning]): bool =
  wc.name == t.getClassName
converter getClass*(t: typedesc[Warning]): WarningClass = WarningClass(name: t.getClassName)
proc getClass*[W: Warning](t: ref W): WarningClass = typeof(t[]).getClass

#TODO:subclass
template issubclass*(x, y: WarningClass): bool = true

