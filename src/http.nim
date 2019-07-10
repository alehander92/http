import strformat, strutils, sequtils, os, osproc
import json, macros
import karax/[karaxdsl, vdom], options, posix, net, asyncnet, asyncdispatch, httpcore, mimetypes, tables, asynchttpserver, norm/sqlite, chronicles, confutils/defs, confutils


# Praise the Lord!

# Have mercy on us, O Lord!

let 
  homePath = os.getHomeDir()

type
  Route* = ref object
    path*: seq[string]
    `method`*: string
    raw*: string

  DB* = ref object

var renderBase* {.compileTime.}: string = currentSourcePath.splitFile[0]


macro updateRenderBase*(path: static[string]): untyped =
  renderBase = path

# adapted from chronicles

type InstantiationInfo = tuple[filename: string, line: int, column: int]

macro renderImpl*(info: static InstantiationInfo, name: static[string]): untyped =
  let path = name.repr[1 .. ^2] & ".nim"
  let source = parseExpr(staticRead(info.filename.splitFile[0].parentDir / "src" / "views" / path))
  result = quote:
    let raw = buildHtml:
      `source`
    (Http200, $raw)

template render*(name: static[string]): untyped =
  renderImpl(instantiationInfo(0, true), name)

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
    when declared(withDB):
      withDB:
        `code`
    else:
      `code`
  result = newProc(nameNode, argsNode, love)


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


template server* =
  mixin createModels
  let httpServer = newAsyncHttpServer(reusePort=true)
  # createModels()
  let serveFut = httpServer.serve(
      port,
      (proc (req: asynchttpserver.Request): Future[void] {.gcsafe, closure.} =
        handleRequest(req)),
      serverName)
  
  asyncCheck serveFut
  runForever()

type
  StartUpCommand* = enum
    example,
    `new`,
    model

  
  HttpOptions* = object
    #
    # This is our configuration type.
    #
    # Each field will be considered a configuration option that may appear
    # on the command-line, whitin an environment variable or a configuration
    # file, or elsewhere. Custom pragmas are used to annotate the fields with
    # additional metadata that is used to augment the behavior of the library.
    #
    log* {.
      desc: "Sets the log level",
      defaultValue: LogLevel.INFO.}: LogLevel
    
    #
    # This program uses a CLI interface with sub-commands (similar to git).
    #
    # The `StartUpCommand` enum provides the list of available sub-commands,
    # but since we are specifying a default value of `noCommand`, the user
    # can also launch the program without entering any particular command.
    # The default command will also be omitted from help messages.
    #
    # Please note that the `logLevel` option above will be shared by all
    # sub-commands. The rest of the nested options will be relevant only
    # when the designated sub-command is being invoked.
    #
    case cmd* {.
      command
      defaultValue: example.}: StartUpCommand

    of example:
      discard

    of `new`:
      project {.argument.}: string

    of model:
      name {.argument.}: string
      

proc readme(project: string): string =
  &"#{project}\n\na web app"

proc nimble(project: string): string =
  &"""
# Package

version       = "0.1.0"
author        = "Fill in"
description   = "A new app"
license       = "MIT"
srcDir        = "src"
bin           = @["{project}"]


# Dependencies

requires "nim >= 0.20.2", "https://github.com/alehander42/http.git#head", "chronicles"
"""

proc gitignore(project: string): string =
  &"""
.o
{project}
"""

proc dir(project: string): string =
  ""

proc source(project: string): string =
  &"""
import http
import model

handler home:
  render "home"

route:
  get "/": home


server()
"""

proc home(project: string): string =
  &"""
html:
  head()
  body:
    text "http page"
"""      

var initModels*: seq[proc: void] = @[]


proc model2(name: string): string =
  &"""
import http

norm:
  type
    {name.capitalizeAscii}* = object
      example*: string

init:
  var {name} = {name.capitalizeAscii}(example: "example")
  {name}.insert()
"""


var types {.compileTime.}: NimNode = nnkStmtList.newTree()
var inits {.compileTime.}: NimNode = nnkStmtList.newTree()

macro norm*(code: untyped): untyped =
  expectKind code[0], nnkTypeSection
  types.add(code[0][0])
  result = quote:
    discard


macro init*(code: untyped): untyped =
  inits.add(code)
  result = quote:
    discard

macro createModels*: untyped =
  result = nnkTypeSection.newTree()
  for t in types:
    result.add(t)
  result = quote:
    db("blog.db", "", "", ""):
      `result`
    addHandler newConsoleLogger()
    withDB:
      createTables(force=true)
      `inits`

  echo result.repr

proc patchModel(name: string): string =
  var lines = readFile("src/model.nim").splitLines()
  var i = 0
  if lines == @[""]:
    lines = @[
      "import",
      "  norm/sqlite,",
      "  http,",
      "",
      "export",
      "",
      "# code",
      ""
    ]
  var linesCount = lines.len
  while i < linesCount:
    let line = lines[i]
    echo line
    if line == "export":
      if lines[i - 2][^1] != ',':
        lines[i - 2].add(",")
      lines.insert(&"  models/{name}", i - 1)
      i += 1
    elif line == "# code":
      if "export" notin lines[i - 2]:
        lines[i - 2].add(",")
      lines.insert(&"  {name}", i - 1)
      break
    i += 1

  result = lines.join("\n") & "\n"


let NAMES = @[
  ("README.md", readme),
  ("$1.nimble", nimble),
  (".gitignore", gitignore),
  ("src/", dir),
  ("src" / "$1.nim", source),
  ("tests/", dir),
  ("src/views/", dir),
  ("src/views/home.nim", home),
  ("src/models/", dir),
  ("src/model.nim", proc(project: string): string = "")
]

let MODEL_NAMES = @[
  ("src/models/$1.nim", model2),
  ("src/model.nim", patchModel)
]

proc newProject(project: string) =
  # for now imitating nimble init a bit but
  # with additional structure
  # creating new project blog
  #   create README.md
  #   create blog.nimble
  #   create .gitignore
  #   create src/
  #   create src/blog.nim
  #   create tests/

  echo &"creating new project {project}"
  try:
    createDir project
  except:
    echo "can't create dir"
    quit(1)
  for (name, view) in NAMES:
    let projectName = name % project
    if projectName[^1] == DirSep:
      try:
        echo &"  create {projectName}"
        createDir project / projectName
      except:
        echo "can't create dir"
        quit(1)
    else:
      echo &"  create {projectName}"
      let source = view(project)
      writeFile(project / projectName, source)

proc newModel(name: string) =
  # for now create models/name.nim
  for (a, view) in MODEL_NAMES:
    let filename = a % name
    echo &"  create {filename}"
    let source = view(name)
    writeFile(filename, source)

when isMainModule:
  let opts = HttpOptions.load()
  case opts.cmd:
  of `new`:
    newProject(opts.project)
  of model:
    newModel(opts.name.toLowerAscii)
  of example:
    discard

export sqlite, karaxdsl, vdom, strformat, asyncnet, asynchttpserver,chronicles
