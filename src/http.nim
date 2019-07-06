import strformat, strutils, sequtils, os, osproc
import json, macros
import karax/[karaxdsl, vdom], options, posix, net, asyncnet, asyncdispatch, httpcore, mimetypes, tables, asynchttpserver, norm/sqlite, chronicles


# Praise the Lord!

let 
  homePath = os.getHomeDir()

type
  Route* = ref object
    path*: seq[string]
    `method`*: string
    raw*: string

  DB* = ref object

var renderBase* {.compileTime.}: string

macro updateRenderBase*(path: static[string]): untyped =
  renderBase = path

macro render*(name: static[string]): untyped =
  let path = name.repr[1 .. ^2] & ".nim"
  let source = parseExpr(staticRead(renderBase / path))
  result = quote:
    let raw = buildHtml:
      `source`
    (Http200, $raw)

# TEMP

let web = "localhost:5000"
let serverName = "localhost"
let port = 5000.PORT
var mimetype = mimetypes.newMimetypes()

let workdir = getAppFilename().splitFile.dir

# loadViews("./views", render)

var routes*: seq[Route] = @[]
var intHandlers*: Table[string, (proc(a: int): (HttpCode, string))] = initTable[string, (proc(a: int): (HttpCode, string))]()
var handlers*: Table[string, (proc(a: string): (HttpCode, string))] = initTable[string, (proc(a: string): (HttpCode, string))]()
var smallHandlers*: Table[string, (proc: (HttpCode, string))] = initTable[string, (proc: (HttpCode, string))]()
var db2* = DB()

macro handler*(args: untyped, code: untyped): untyped =

  var nameNode: NimNode
  var argsNode: seq[NimNode]
  argsNode.add(quote do: (HttpCode, string))
  case args.kind
  of nnkObjConstr:
    nameNode = args[0]
    for i, arg in args:
      if i > 0:
        argsNode.add(nnkIdentDefs.newTree(arg[0], arg[1], newEmptyNode()))
  of nnkIdent:
    nameNode = args
  else:
    assert false, "expected nnkObjConst or nnkIdent"
  let love = quote:
    withDB:
      `code`
  result = newProc(nameNode, argsNode, love)
  echo result.repr
  
macro route*(routes: untyped): untyped =
  result = nnkStmtList.newTree()
  for element in routes:
    expectKind element, nnkCommand 
    let methodNode = newLit(element[0].repr)
    let rawNode = element[1]
    let function = element[2][0]
    var path = rawNode.repr[1 .. ^2].split('/')
    path.delete(0, 0)
    var pathNode = nnkPrefix.newTree(ident"@", nnkBracket.newTree())
    for p in path:
      pathNode[1].add(newLit(p))
    let methodField = nnkAccQuoted.newTree(ident"method")
    var routeCode = quote:
      routes.add(Route(path: `pathNode`, `methodField`: `methodNode`, raw: `rawNode`))
    result.add(routeCode)
    var handlers = ident""
    if ":int" in rawNode.repr:
      handlers = ident"intHandlers"
    elif '@' in rawNode.repr:
      handlers = ident"handlers"
    else:
      handlers = ident"smallHandlers"
    var handlerCode = quote:
      `handlers`[`rawNode`] = `function`
    result.add(handlerCode)
  echo result.repr

proc routeAccepts(route: Route, path: seq[string], `method`: HttpMethod): (bool, HttpCode, string) =
  result = (false, Http404, "")
  if $`method` != route.`method`.toUpperAscii:
    return
  var intArg = -1
  var arg = ""
  debug "route", path = $path, route = $route.path
  for i, pathElement in route.path:
    if i >= path.len:
      return
    debug "pathElement", pathElement, pathi=path[i]
    if ':' in pathElement:
      let a = pathElement.split(':', 2)
      let name = a[0][1 .. ^1]
      let typ = a[1]
      if typ == "int":
        if path[i].isDigit():
          intArg = path[i].parseInt()
          debug "int arg", intArg
      else:
        return
    elif pathElement.len > 0 and pathElement[0] == '@':
      let name = pathElement[1 .. ^1]
      arg = path[i]
    else:
      if pathElement != path[i]:
        debug "not equal"
        return
  result[0] = true
  if intArg != -1:
    if intHandlers.hasKey(route.raw):
      (result[1], result[2]) = intHandlers[route.raw](intArg)
    else:
      result[0] = false
      return
  elif arg != "":
    if handlers.hasKey(route.raw):
      (result[1], result[2]) = handlers[route.raw](arg)
    else:
      result[0] = false
      return
  else:
    if smallHandlers.hasKey(route.raw):
      (result[1], result[2]) = smallHandlers[route.raw]()
    else:
      result[0] = false
      return

# those are adapted from Jester
# thanks!
# credits to dom96

proc send(request: asynchttpserver.Request, code: HttpCode, raw: string, kind: string) =
  try:  
    var headers = newHttpHeaders(@({
      "content-type": mimetype.getMimetype(kind) & (if kind == "html": ";charset=utf8" else: ""),
      "content-length": $raw.len
    }))
    debug "headers", headers
    asyncCheck request.respond(code, raw, headers)
  except:
    echo osErrorMsg(osLastError())
    quit(1)

proc handleRequest(httpReq: asynchttpserver.Request): Future[void] =
  debug "handleRequest"
  let path = httpReq.url.path.split('/')[1 .. ^1]

  var handled = false
  for route in routes:
    debug "route?", route=route.raw
    let res = routeAccepts(route, path, httpReq.reqMethod)
    debug "res", res
    if res[0]:  
      send(httpReq, res[1], res[2], "html")
      handled = true
      break
  if not handled:
    debug "not existing"
    send(httpReq, Http404, "page not existing", "html")
  let future = newFuture[void]()
  complete(future)
  return future

proc server* =
  let httpServer = newAsyncHttpServer(reusePort=true)
  let serveFut = httpServer.serve(
      port,
      (proc (req: asynchttpserver.Request): Future[void] {.gcsafe, closure.} =
        handleRequest(req)),
      serverName)
  asyncCheck serveFut
  runForever()


export sqlite, karaxdsl, vdom, strformat
