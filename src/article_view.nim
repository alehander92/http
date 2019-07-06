html:
  head()
    # link(`type`="text/css", rel="stylesheet", href="/public/style.css")
  body:
    tdiv(class="title"):
      text a.title
    tdiv(class="author"):
      text a.author
    tdiv(class="text"):
      text a.text
