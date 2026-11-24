
var filters_version* = 1

#TODO:lock
template wmLock*(body) = body
template wmMutLock*(body) =
  bind filters_version, wmLock
  wmLock:
    body
    filters_version += 1

