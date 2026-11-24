
import std/strutils
import std/options
import pkg/pyrepr
include ./comm
import ./utils
export utils except getClass
type
  WarningMessage* = ref object
    message*: ref Warning
    category*: WarningClass
    filename*: string
    lineno*: int
    file*: File
    line*: Option[string]

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
  result.category = category.getClass
  st filename
  st lineno
  st file
  st line

proc `$`*(self: WarningMessage): string =
  template r(s): untyped = pyrepr(s)
  "{message : $#, category : $#, filename : $#, lineno : $#, line : $#}" %
    [self.message.repr, self.category.name.r, self.filename.r, self.lineno.`$`,
      if self.line.isSome: self.line.unsafeGet.r
      else: "None"
    ]

proc repr*(self: WarningMessage): string = "<warnings.WarningMessage " & $self & '>'

