## base impl of Python's Lib/warnings
##
## Q: why this exists here?
## A: as warnings.showwarning's `file` param type is `File`,
##   which dep this pkg; while this pkg dep warnings too (in initBufAsPy)

import ./warnings/[warncls, internal_types, impl, dbg]
export warncls, impl, dbg
export internal_types except newWarningMessage, WarningMessage, WarningClass

