import 'package:html/dom.dart' hide Text;

import 'scraper.dart';

class LibgenResult {
  String title;
  List<String> links;

  LibgenResult({this.title = "", this.links});

  get complete => title != "" && links != null;

  addLink(String link) {
    if (this.links == null) {
      this.links = new List<String>();
    }

    this.links.add(link);
  }
}

class Libgen {
  get home => 'http://libgen.is/';
  get numResult => 100;

  getQueryString(String input) {
    var splitInput = input.split(" ");
    var joinedInput = splitInput.join("+");
    return "search.php?req=$joinedInput&lg_topic=libgen&open=0&view=simple&res=$numResult&phrase=1&column=def";
  }

  _getData(WebScraper webScraper) {
    final List<Element> trs = webScraper.getElements('table.c > tbody > tr');
    final results = List<LibgenResult>();

    for (var tr in trs) {
      var result = LibgenResult();
      var isEpub = false;

      for (var td in tr.children) {
        if (td.attributes["width"] == "500") {
          final title = _extractTitle(td);
          if (title == "") {
            throw Exception();
          }

          result.title = title;
          continue;
        }

        final link = _extractLink(td);
        if (link == "") {
          if (td.attributes.containsKey("nowrap") && td.innerHtml == "epub") {
            isEpub = true;
          }
          continue;
        }

        if (isEpub) {
          result.addLink(link);
        }
      }

      if (result.complete) {
        results.add(result);
      }
    }

    return results;
  }

  performSearch(String input) async {
    var searchQuery = getQueryString(input);
    final webScraper = WebScraper(home);

    if (await webScraper.loadWebPage(searchQuery)) {
      return _getData(webScraper);
    }
  }

  String _extractTitle(Element td) {
    for (var child in td.children) {
      if (child.attributes.containsKey("title")) {
        for (var grandchild in child.nodes) {
          if (grandchild.nodeType == Node.TEXT_NODE) {
            final trimmed = grandchild.text.trim();
            if (trimmed == "") {
              continue;
            }
            return trimmed;
          }
        }
      }
    }

    return "";
  }

  String _extractLink(Element td) {
    for (var child in td.children) {
      if (child.attributes.containsKey("href") &&
          child.attributes.containsKey("title") &&
          child.attributes["title"] != "Libgen Librarian") {
        return child.attributes["href"];
      }
    }
    return "";
  }

  extractSecondLevelLink(String link) async {
    final uri = Uri.parse(link);
    final scraper = WebScraper(uri.origin);

    if (await scraper.loadWebPage(uri.path)) {
      final List<Element> as = scraper.getElements('h2 > a');
      if (as.length > 0) {
        return as[0].attributes['href'];
      }
    }

    return '';
  }
}
