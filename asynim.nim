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

proc buildPage(content,buttons,placeholderContent, tableData, title,str1,str2: string): string =
  let secondHeading = """<div align="center" class="mt-3 text-warning"><h3>{{heading}}</div> """.replace("{{heading}}",str1) 
  result = content.replace("{{ title }}", title(title))
  result = result.replace("{{ main_heading }}", h1("Это страница ", span(str2, class="text-warning")))
  result = result.replace("{{ content }}", buttons & secondHeading & placeholderContent & tableData)
  result = result.replace("{{heading}}", "Информация о руководителе")

proc createButtons(pathSpl: seq[string]): Future[string] {.async.} =
  result = await getFileData(templates  / "buttons.html")
  case pathSpl[0]:
  of "shop":
    result = result.replace("{{link1}}","/content/shop/staff")
    result = result.replace("{{name1}}","Персонал")
    result = result.replace("{{link2}}","/content/shop/goods")
    result = result.replace("{{name2}}","Товары")
    result = result.replace("{{link3}}","/content/shop/cash")
    result = result.replace("{{name3}}","Кассы")
  of "shelter":
    result = result.replace("{{link1}}","/content/shelter/managers")
    result = result.replace("{{name1}}","Руководители")
    result = result.replace("{{link2}}","/content/shelter/staff")
    result = result.replace("{{name2}}","Персонал")
    result = result.replace("{{link3}}","/content/shelter/pets")
    result = result.replace("{{name3}}","Питомцы")
  of "school":
    result = result.replace("{{link1}}","/content/school/director")
    result = result.replace("{{name1}}","Директор")
    result = result.replace("{{link2}}","/content/school/teachers")
    result = result.replace("{{name2}}","Учителя")
    result = result.replace("{{link3}}","/content/school/students")
    result = result.replace("{{name3}}","Ученики")

proc createTableRow(num,par,val: string): string = 
  result = """<tr><th scope="row">$1</th><td>$2</td><td>$3</td></tr>""" % [num,par,val]

proc notFound(content: string): Future[string] {.async.} =
  result = content.replace("{{ title }}", title("404"))
  result = result.replace("{{ main_heading }}", h1("Страница не найдена :(", class="text-danger"))
  result = result.replace("{{ content }}", "")


proc getApiPage(path: string, r: Request): Future[string] {.async.} =
  let pathSpl = path.split("/").filterIt(it != "")
  let placeholderids = {1..10}.toSeq
  var placeholderContent: JsonNode = newJObject()
  placeholderContent["<rootname2>"] = newJArray()
  for id in placeholderids:
    placeholderContent["<rootname2>"].add(%*{"ID": id, "url": "/api/v1/<rootname1>/<rootname2>/$1" % $id})
  case pathSpl.len:
  of 0:
    result = (
      %*{"data": 
        {"shop": apiPrefix & "/shop",
        "shelter": apiPrefix & "/shelter",
        "school": apiPrefix & "/school"}
      }).pretty
  of 1:
    result = case pathSpl[0]:
    of "shop": (
      %*{"shop": 
        {"staffUrl": apiPrefix & "/shop/staff",
        "goodsUrl": apiPrefix & "/shop/goods",
        "cashUrl": apiPrefix & "/shop/cash"}
      }).pretty
    of "shelter": (
      %*{"shelter": 
        {"staffUrl": apiPrefix & "/shelter/staff",
        "petsUrl": apiPrefix & "/shelter/pets",
        "managersUrl": apiPrefix & "/shelter/managers"}
      }).pretty
    of "school": (
      %*{"school": 
        {"directorUrl": apiPrefix & "/school/director",
        "teachersUrl": apiPrefix & "/school/teachers",
        "studentsUrl": apiPrefix & "/school/students"}
      }).pretty
    else: (%*{"error": "Unknown API"}).pretty
  of 2:
    case pathSpl.join("/"):
    of "shop/staff": result = placeholderContent.pretty.replace("<rootname1>","shop").replace("<rootname2>","staff")
    of "shop/cash": result = placeholderContent.pretty.replace("<rootname1>","shop").replace("<rootname2>","cash")
    of "shop/goods": result = placeholderContent.pretty.replace("<rootname1>","shop").replace("<rootname2>","goods")
    of "shelter/managers": result = placeholderContent.pretty.replace("<rootname1>","shelter").replace("<rootname2>","managers")
    of "shelter/staff": result = placeholderContent.pretty.replace("<rootname1>","shelter").replace("<rootname2>","staff")
    of "shelter/pets": result = placeholderContent.pretty.replace("<rootname1>","shelter").replace("<rootname2>","pets")
    of "school/director": result = (
                            %*{"director": 
                              {"ID": 0,
                              "firstame": "some_name",
                              "lastName": "some_surname",
                              "birthDate": "01.01.1999"}
                            }).pretty
    of "school/teachers": result = placeholderContent.pretty.replace("<rootname1>","school").replace("<rootname2>","teachers")
    of "school/students": result = placeholderContent.pretty.replace("<rootname1>","school").replace("<rootname2>","students")
    else: result =  (%*{"error": "Unknown API"}).pretty
  of 3:
    if (pathSpl[0..1].join("/") == "shop/staff") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"staff": 
          {"ID": $pathSpl[2],
          "firstame": "some_name",
          "lastName": "some_surname",
          "birthDate": "01.01.1999",
          "post": "some_post"}
        }).pretty
    elif (pathSpl[0..1].join("/") == "shop/cash") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"cash": 
          {"ID": $pathSpl[2],
          "number": 0,
          "free": true,
          "totalCash": 0}
        }).pretty
    elif (pathSpl[0..1].join("/") == "shop/goods") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"good": 
          {"ID": $pathSpl[2],
          "title": "some_title",
          "price": 0,
          "endDate": "01.01.1999",
          "discount": 0,
          "count": 0}
        }).pretty
    elif (pathSpl[0..1].join("/") == "shelter/managers") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"manager": 
          {"ID": $pathSpl[2],
          "firstame": "some_name",
          "lastName": "some_surname",
          "birthDate": "01.01.1999",
          "post": "some_post"}
        }).pretty
    elif (pathSpl[0..1].join("/") == "shelter/staff") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"staff": 
          {"ID": $pathSpl[2],
          "firstame": "some_name",
          "lastName": "some_surname",
          "birthDate": "01.01.1999",
          "uid": 0}
        }).pretty
    elif (pathSpl[0..1].join("/") == "shelter/pets") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"pet": 
          {"ID": $pathSpl[2],
          "name": "some_name",
          "age": 0}
        }).pretty
    elif (pathSpl[0..1].join("/") == "school/teachers") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"teacher": 
          {"ID": $pathSpl[2],
          "firstame": "some_name",
          "lastName": "some_surname",
          "birthDate": "01.01.1999",
          "subject": "some_subject"}
        }).pretty
    elif (pathSpl[0..1].join("/") == "school/students") and pathSpl[2].match(re"^\d+$"):
      result = (
        %*{"student": 
          {"ID": $pathSpl[2],
          "firstame": "some_name",
          "lastName": "some_surname",
          "birthDate": "01.01.1999",
          "classNum": 0,
          "classLet": "A"}
        }).pretty
    else: result = (%*{"error": "Unknown API"}).pretty
  else: result = (%*{"error": "Unknown API"}).pretty

proc getPage(path, content: string, r: Request): Future[string] {.async.} =
  let pathSpl = path.split("/").filterIt(it != "")
  let  buttons = await createButtons(pathSpl)
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
      item = item.replace("{{ link }}", "/content/$1/$2" % [pathSpl.join("/"), $id])
      item = item.replace("{{ api_link }}", "$1/$2/$3" % [apiPrefix, pathSpl.join("/"), $id])
      temp.add(item)
    placeholder = placeholder.replace("{{ holder }}", temp.join("\n"))
    placeholderContent &= placeholder
  ## END PLACEHOLDERS
  case pathSpl.len:
  of 1:
    case pathSpl[0]:
    of "shop":
      result = content.buildPage(buttons,"", "", "Магазин","","магазина")
    of "shelter":
      result = content.buildPage(buttons,"", "", "Приют","","приюта") 
    of "school":
      result = content.buildPage(buttons,"", "", "Школа","","школы") 
    else: result = await content.notFound
  of 2:
    case pathSpl.join("/"):
    of "shop/staff":
      result = content.buildPage(buttons,placeholderContent,"", "Персонал магазина","Персонал","магазина")
    of "shop/cash":
      result = content.buildPage(buttons,placeholderContent,"", "Кассы магазина","Кассы","магазина") 
    of "shop/goods":
      result = content.buildPage(buttons,placeholderContent,"", "Товары магазина","Товары","магазина") 
    of "shelter/managers":
      result = content.buildPage(buttons,placeholderContent,"", "Руководители приюта","Руководители","приюта")  
    of "shelter/staff":
      result = content.buildPage(buttons,placeholderContent,"", "Персонал приюта","Персонал","приюта") 
    of "shelter/pets":
       result = content.buildPage(buttons,placeholderContent,"", "Питомцы приюта","Питомцы","приюта") 
    of "school/director": 
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID","1")
      tableRows &= createTableRow("2","firstname","some_name")
      tableRows &= createTableRow("3","lastname","some_name")
      tableRows &= createTableRow("4","birthDate","01.01.1999")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Директор школы","Информация о директоре","школы")
    of "school/teachers":
      result = content.buildPage(buttons,placeholderContent,"", "Учителя школы","Учителя","школы") 
    of "school/students":
      result = content.buildPage(buttons,placeholderContent,"", "Ученики школы","Ученики","школы")
    else: result = await content.notFound
  of 3:
    if (pathSpl[0..1].join("/") == "shop/staff") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","firstname","some_name")
      tableRows &= createTableRow("3","lastname","some_name")
      tableRows &= createTableRow("4","birthDate","01.01.1999")
      tableRows &= createTableRow("5","post","some_post")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Персонал магазина","Информация о сотруднике","магазина")
    elif (pathSpl[0..1].join("/") == "shop/cash") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","number","0")
      tableRows &= createTableRow("3","free","true")
      tableRows &= createTableRow("4","totalCash","0")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Кассы магазина","Информация о кассе","магазина")
    elif (pathSpl[0..1].join("/") == "shop/goods") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","title","some_title")
      tableRows &= createTableRow("3","price","0")
      tableRows &= createTableRow("4","endDate","01.01.1999")
      tableRows &= createTableRow("5","discount","0")
      tableRows &= createTableRow("6","count","0")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Товары магазина","Информация о товаре","магазина")
    elif (pathSpl[0..1].join("/") == "shelter/managers") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","firstname","some_name")
      tableRows &= createTableRow("3","lastname","some_name")
      tableRows &= createTableRow("4","birthDate","01.01.1999")
      tableRows &= createTableRow("5","post","some_post")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Руководители приюта","Информация о руководителе","приюта")
    elif (pathSpl[0..1].join("/") == "shelter/staff") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","firstname","some_name")
      tableRows &= createTableRow("3","lastname","some_name")
      tableRows &= createTableRow("4","birthDate","01.01.1999")
      tableRows &= createTableRow("5","uid","0")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Сотрудники приюта","Информация о сотруднике","приюта")
    elif (pathSpl[0..1].join("/") == "shelter/pets") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","tname","some_name")
      tableRows &= createTableRow("3","age","0")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Питомцы приюта","Информация о питомце","приюта")
    elif (pathSpl[0..1].join("/") == "school/teachers") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","firstname","some_name")
      tableRows &= createTableRow("3","lastname","some_name")
      tableRows &= createTableRow("4","birthDate","01.01.1999")
      tableRows &= createTableRow("5","subject","some_subject")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Учителя школы","Информация об учителе","школы")
    elif (pathSpl[0..1].join("/") == "school/students") and pathSpl[2].match(re"^\d+$"):
      var tableData = await getFileData(templates  / "table.html")
      var tableRows = createTableRow("1","ID",$pathSpl[2])
      tableRows &= createTableRow("2","firstname","some_name")
      tableRows &= createTableRow("3","lastname","some_name")
      tableRows &= createTableRow("4","birthDate","01.01.1999")
      tableRows &= createTableRow("5","classNum","0")
      tableRows &= createTableRow("5","classLet","A")
      tableData  = tableData.replace("{{tableData}}", tableRows)
      result = content.buildPage(buttons,"",tableData, "Ученики школы","Информация об ученике","школы")
    else: result = await content.notFound
  else: result = await content.notFound

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
