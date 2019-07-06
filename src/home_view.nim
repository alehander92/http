html:
  head()
    # link(`type`="text/css", rel="stylesheet", href="/public/style.css")
  body:
    tdiv(class="home"):
      text "blog"
      for a in articles:
        tdiv:
          a(href = &"/article/{a.id}"):
            text a.title