http
==============

TODO: not in nimble, for now clone it

```
nimble install http
```


## Introduction

http is a web lib

``` nim
import http

# norm

norm:
  type
    Article = object
      title: string
      author: string
      text: string

init:
  var article = Article(
    title: "title",
    author: "author",
    text: "")
  article.insert()

createModels()

handler home:
  var articles = Article.getMany(20)
  render "home_view"

handler article(id: int):
  var a = Article.getOne("id=?", id)
  render "article_view"

route:
  get "/article/@id:int": article
  get "/": home


server()
```

It is just a pipeline using

* nim's `asynchttpserver` as a server
* [https://moigagoo.github.io/norm/norm.html](norm (by moigagoo)) as an orm
* [https://github.com/pragmagic/karax](karax (by Araq)) as a template engine
* [https://github.com/status-im/nim-chronicles](chronicles (by status-im)) as a logging tool
* nim-confutils

The current code is mostly an early alpha version and some of it is adapted from [https://github.com/dom96/jester/](jester (by dom96)): credits!

The goal is to define a phoenix/rails-like framework with

* validation dsl
* swappable orm / view etc layers
* good websocket/client framework interop

## Create a project

A new project is created similarly to rails: you can enter a command which fills in a directory with start files with structure based on nimble init

```bash
> http new --project=blog

creating new project blog
  create README.md
  create blog.nimble
  create .gitignore
  create src/
  create src/blog.nim
  create tests/
  create views/
  create views/home.nim
```

create a model

```bash
> http model --name=article

  create src/models/article.nim
  patch src/model.nim
```

## Contributing


Would love any ideas and contributions. Keep in mind you can also contribute to [https://github.com/dom96/jester/](jester by dom96) or [https://github.com/andreaferretti/rosencrantz](rosencrantz by andreaferretti)

## License

Licensed and distributed under
* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

