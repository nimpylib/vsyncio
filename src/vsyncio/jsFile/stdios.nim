

import pkg/handy_sugars/assumes
import pkg/jscompat/utils/[dispatch, deno]
from ./private/helpers import jsExpr
from ./open/decl import File
import ./stdio
import ./bufferedio
from ./rawio import newFileIO

type FileHandle = stdio.FileHandle  # shadow system's syncio.FileHandle
type File = decl.File  # shadow system's syncio.File

var stdin*, stdout*, stderr*: File

proc new*[F: BufferedIOBase](name: string, filehandle: int|FileHandle, mode: FileMode;
                   seekable = when F is StdioFile: false else: true): F =
  F(raw: newFileIO(FileHandle filehandle, seekable, name,
    writable = mode != fmRead, append = mode == fmAppend))

proc newStdFile(name: string, filehandle: int, mode: FileMode): File =
  if inDeno:
    let denoFile = case filehandle
      of 0: jsExpr"Deno.stdin"
      of 1: jsExpr"Deno.stdout"
      of 2: jsExpr"Deno.stderr"
      else:
        unreachable
    StdioFile(raw: newFileIO(FileHandle filehandle, seekable = false, name = name,
      writable = mode != fmRead, append = mode == fmAppend,
      denoFile = denoFile, isDenoFile = true))
  else:
    new[StdioFile](name, filehandle, mode)

stdin  = newStdFile("<stdin>",  0, fmRead)
stdout = newStdFile("<stdout>", 1, fmWrite)
stderr = newStdFile("<stderr>", 2, fmWrite)

