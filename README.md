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

db("blog.db", "", "", ""):
  type
    Article = object
      title: string
      author: string
      text: string

withDb:                                   # Start a DB session.
  createTables(force=true)                # Create tables for objects. Drop tables if they exist.

  var article = Article(
    title: "title",
    author: "author",
    text: "")
  article.insert()

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

The current code is mostly an early alpha version and some of it is adapted from [https://github.com/dom96/jester/](jester (by dom96)): credits!

The goal is to define a phoenix/rails-like framework with

* validation dsl
* swappable orm / view etc layers
* good websocket/client framework interop

## Contributing


Would love any ideas and contributions. Keep in mind you can also contribute to [https://github.com/dom96/jester/](jester by dom96) or [https://github.com/andreaferretti/rosencrantz](rosencrantz by andreaferretti)

## License

Licensed and distributed under
* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

