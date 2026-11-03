
template gen*(name; nameDef) {.dirty.} =
  when defined(js):
    import ../../jsFile as fileobj_js
    export name
  else:
    nameDef

