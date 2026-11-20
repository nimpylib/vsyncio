
import std/strutils
import std/options
include ./comm
import ./utils
export utils except getClass
type
  WarningMessage* = ref object
    message*: ref Warning
    #category: WarningClass  #see below
    `-category_name`: string
    filename*: string
    lineno*: int
    file*: File
    line*: Option[string]
template category*(self: WarningMessage): auto = WarningClass(name: self.`-category_name`)

const None = none string
#const DefWarning = WarningClass(name: "UserWarning")  ## reprenset the `warning = None` in python. \
  ## as document, it defaults to UserWarning

proc newWarningMessage*(message: string|(ref Warning); category;
                       filename; lineno; file: File = nil; line = None): auto =
  when message is string:
    let message = newException(category, message)
  result = new WarningMessage
  template st(a) = result.a = a
  st message
  result.`-category_name` = category.getClass.name
  st filename
  st lineno
  st file
  st line

