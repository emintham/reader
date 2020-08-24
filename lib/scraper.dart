import 'dart:async';

import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:html/dom.dart';

class WebScraper {
  // Response Object of web scrapping the website
  var _response;

  // time elapsed in loading in milliseconds
  int timeElapsed;

  // base url of the website to be scrapped
  String baseUrl;

  /// Creates the web scraper instance
  WebScraper(String baseUrl) {
    if (baseUrl == '' || baseUrl == null)
      throw WebScraperException(
          "Base Url cannot be empty inside the constructor");
    this.baseUrl = baseUrl;
  }

  /// Loads the webpage into response object
  Future<bool> loadWebPage(String route) async {
    if (baseUrl != null || baseUrl != '') {
      final stopwatch = Stopwatch()..start();
      var client = Client();
      try {
        _response = await client.get(baseUrl + route);
        // Calculating Time Elapsed using timer from dart:core
        if (_response != null) {
          timeElapsed = stopwatch.elapsed.inMilliseconds;
          stopwatch.stop();
          stopwatch.reset();
        }
      } catch (e) {
        print(e.message);
        throw WebScraperException(e.message);
      }
      return true;
    }
    return false;
  }

  List<Element> getElements(String address) {
    if (_response == null)
      throw WebScraperException(
          "getElement cannot be called before loadWebPage");
    // Using html parser and query selector to get a list of particular element
    var document = parse(_response.body);
    return document.querySelectorAll(address);
  }
}

class WebScraperException implements Exception {
  var _message;

  WebScraperException(String message) {
    this._message = message;
  }

  String errorMessage() {
    return _message;
  }
}
