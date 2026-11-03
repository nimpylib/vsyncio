
import std/macros
template emptyn: untyped = newEmptyNode()
proc newProc(name, params, body: NimNode, kind = nnkProcDef, pragmas = newEmptyNode()): NimNode =
  kind.newTree(
    name, emptyn, emptyn,
    params,
    pragmas,
    emptyn,
    body)

macro expBufInArr*(def) =
  def.expectKind {nnkProcDef, nnkMethodDef, nnkFuncDef}
  let params = def.params
  var
    params1 = params.copyNimNode.add params[0]
    params2 = params.copyNimNode.add params[0]
  var args: seq[NimNode]
  var needRewrite = false
  for i in 1..<params.len:
    let
      p = params[i]
      p1 = p.copyNimNode
      p2 = p.copyNimNode
    let typIdx = p.len-2
    for j in 0..<typIdx:
      let pj = p[j]
      args.add pj
      p1.add pj
      p2.add pj
    let typ = p[typIdx]
    if typ.kind == nnkBracketExpr and
        typ[0].eqIdent"TypedArray" and typ[2].eqIdent"auto":
      needRewrite = true
      template tArrOf(buf): untyped =
        nnkBracketExpr.newTree(ident"TypedArray", typ[1], buf)
      params1.add p1.add(tArrOf ident"SharedArrayBuffer", emptyn)
      params2.add p2.add(tArrOf ident"ArrayBuffer", emptyn)
    else:
      params1.add p
      params2.add p
  if not needRewrite:
    return def
  result = newStmtList()
  # proc .... = body
  let
    defname = def.name
    name = defname.basename.strVal
    genName = genSym(nskProc, name)
  result.add newProc(
    genName,
    params,
    def.body)

  # `method .... = ..` x 2
  template readd(ps) =
    let m = newProc(def[0], ps,
      newCall(genName).add(args),
      def.kind,
      def.pragma,
    )
    result.add m

  readd params1
  readd params2

