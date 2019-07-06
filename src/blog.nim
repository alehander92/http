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
