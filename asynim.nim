import asynchttpserver
import asyncdispatch
import asyncfile
import htmlgen, json
import re, sequtils, strutils
import os

const apiPrefix = "/api/v1"
const templates = "templates/"
const staticDir = "static/"


proc getFileData(filename: string): Future[string] {.async.} =
  let file = openAsync(getAppDir() / filename)
  result = await readAll(file)
  file.close()


proc notFound(content: string): Future[string] {.async.} =
  result = content.replace("{{ title }}", title("404"))
  result = result.replace("{{ main_heading }}", h1("Страница не найдена :(", class="text-danger"))
  result = result.replace("{{ content }}", "")


proc getApiPage(path: string, r: Request): Future[string] {.async.} =
  ## Продумайте эндпоинты для всех атрибутов соответствующих объектов
  ## Например, /api/v1/shop показывает эндпоинты: {"Cash": "url": "/api/v1/shop/cash", "Staff": ...}
  ## А /api/v1/shop/cash отображает 10 PLACEHOLD элементов: {"ID": 1, "url": "/api/v1/shop/cash/1"}
  ## /api/v1/shop/cash/1 отображает подробную информацию о кассе
  ## И так далее.
  let placeholderids = {1..10}.toSeq
  result = case path:
  of "/": (
      %*{"data": 
        {"shop": apiPrefix & "/shop",
        "shelter": apiPrefix & "/shelter",
        "school": apiPrefix & "/school"}
      }).pretty
  of "/shop": (%*{"message": "Заглушка API магазина"}).pretty
  of "/shelter": (%*{"message": "Заглушка API приюта"}).pretty
  of "/school": (%*{"message": "Заглушка API школы"}).pretty
  else: (%*{"error": "Unknown API"}).pretty


proc getPage(path, content: string, r: Request): Future[string] {.async.} =
  let root = path.split("/")[0]
  # Так можно получить id, если он есть
  let id = if path.find(re"\d+") != -1: path.findAll(re"\d+")[0].parseInt else: -1
  ## PLACEHOLDERS
  let placeholderids = {1..10}.toSeq.distribute(4)
  var placeholderContent: string
  for items in placeholderids:
    var placeholder: string = `div`("{{ holder }}", class="my-3 d-flex flex-row justify-content-center")
    var temp: seq[string]
    for id in items:
      var item = await getFileData(templates  / "card.html")
      item = item.replace("{{ title }}", $id)
      item = item.replace("{{ subtitle }}", "Заглушка")
      item = item.replace("{{ description }}", "Простая заглушка под нужные данные")
      item = item.replace("{{ link }}", "/content/$1/$2" % [root, $id])
      item = item.replace("{{ api_link }}", "$1/$2/$3" % [apiPrefix, root, $id])
      temp.add(item)
    placeholder = placeholder.replace("{{ holder }}", temp.join("\n"))
    placeholderContent &= placeholder
  ## END PLACEHOLDERS
  if root == "shop":
    case id:
    of -1:
      result = content.replace("{{ title }}", title("Магазин"))
      result = result.replace("{{ main_heading }}", h1("Это страница ", span("магазина", class="text-warning")))
      result = result.replace("{{ content }}", placeholderContent)
    else:
      ## Проработайте заглушки страниц для сотрудников, касс и товаров
      ## В качестве основы для эндпоинтов используйте созданные вами объекты проекта db-enjoyer
  elif root == "shelter":
    case id:
    of -1:
      result = content.replace("{{ title }}", title("Приют"))
      result = result.replace("{{ main_heading }}", h1("Это страница ", span("приюта", class="text-warning")))
      result = result.replace("{{ content }}", placeholderContent)
    else:
      ## Проработайте заглушки страниц для менеджеров, сотрудников и питомцев
      ## В качестве основы для эндпоинтов используйте созданные вами объекты проекта db-enjoyer
  elif root == "school":
    case id:
    of -1:
      result = content.replace("{{ title }}", title("Школа"))
      result = result.replace("{{ main_heading }}", h1("Это страница ", span("школы", class="text-warning")))
      result = result.replace("{{ content }}", placeholderContent)
    else:
      ## Проработайте заглушки страниц для директора, учителей и учеников
      ## В качестве основы для эндпоинтов используйте созданные вами объекты проекта db-enjoyer
  else:
    result = await content.notFound


proc main(r: Request) {.async.} =
  let base = await getFileData(templates / "base.html")
  var page = base
  page = page.replace("{{ navbar }}", await getFileData(templates / "includes" / "nav.html"))

  let path = r.url.path
  if path == "/":
    page = page.replace("{{ title }}", title("Главная страница"))
    page = page.replace("{{ main_heading }}", h1("Это главная страница"))
    page = page.replace("{{ content }}", "")
    await r.respond(Http200, page)
  elif path.startsWith("/static/"):
    let filePath = staticDir / path[8..^1]
    if fileExists(filePath):
      await r.respond(Http200, await getFileData(filePath))
  elif path.startsWith("/content/"):
    await r.respond(Http200, await getPage(path[9..^1], page, r))
  elif path.startsWith(apiPrefix):
    await r.respond(
      Http200,
      await getApiPage(path[7..^1], r),
      newHttpHeaders({"Content-Type": "application/json"}))
  else:
    await r.respond(Http404, await page.notFound)

when isMainModule:
  let server = newAsyncHttpServer()
  let port = Port(8080)
  waitFor server.serve(port, main)
