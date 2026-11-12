
template genImpl(imported; name; nameDef) {.dirty.} =
  when defined(js):
    import imported as fileobj_js
    export name
  else:
    nameDef

template gen*(name; nameDef) {.dirty.} =
  bind genImpl
  genImpl(../../jsFile, name, nameDef)

template genBase*(name; nameDef) {.dirty.} =
  bind genImpl
  genImpl(../../jsFile/iobase, name, nameDef)
