
when defined(js):
  import std/unittest
  import vsyncio as nio

  type
    CaptureFile = ref object of nio.File
      lines: seq[string]

  method writeLine*(f: CaptureFile, s: string) =
    f.lines.add s

  test "redirect stdout to seq[string]":
    let cap = CaptureFile()
    let prev = nio.stdout
    nio.stdout = cap
    nio.stdout.writeLine("hello")
    nio.stdout.writeLine("world")
    nio.stdout = prev
    check cap.lines == @["hello", "world"]
