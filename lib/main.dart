import 'dart:core';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:reader/libgen.dart';
import 'package:open_file/open_file.dart';

void main() async {
  await Hive.initFlutter();
  final box = await Hive.openBox("toDownload");
  box.clear();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(body: HomePage()),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  var _results = List<LibgenResult>();
  var _isLoading = false;
  var _pageIndex = 0;
  var _currentDownload = -1;
  var _percentDownloaded = 0.0;

  Box get box => Hive.box("toDownload");

  @override
  void dispose() async {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            title: Text('Search'),
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            title: Text('Not Found'),
          ),
        ],
        currentIndex: _pageIndex,
        onTap: _handlePageNav,
      ),
      body: _pageIndex == 0 ? buildSearchPage() : buildNotYetDownloadedPage(),
    );
  }

  Column buildSearchPage() {
    return Column(
      children: [
        buildForm(),
        Divider(
          height: 10,
        ),
        if (!_isLoading) Expanded(child: buildResultList()),
        if (_isLoading) buildLoadingState(),
      ],
    );
  }

  Form buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          buildSearchField(),
          buildSearchButton(),
        ],
      ),
    );
  }

  RaisedButton buildSearchButton() {
    return RaisedButton(
      onPressed: () {
        if (_formKey.currentState.validate()) {
          _formKey.currentState.save();
          setState(() {
            _isLoading = true;
          });
        }
      },
      child: Text("Search"),
    );
  }

  Container buildSearchField() {
    return Container(
      margin: EdgeInsets.only(
        top: 40,
        left: 20,
        right: 20,
        bottom: 10,
      ),
      child: TextFormField(
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Search',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
        ),
        validator: (value) {
          if (value.isEmpty) {
            return 'Please enter some text';
          }
          return null;
        },
        onSaved: performSearch,
      ),
    );
  }

  performSearch(String input) async {
    FocusScope.of(context).unfocus();
    var results = List<LibgenResult>();
    try {
      results = await Libgen().performSearch(input);
    } catch (e) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text("Exception reaching website ${e.message}"),
        ),
      );
      return;
    }

    print("Found ${results.length} results");

    if (results.length == 0) {
      box.put(input, "");

      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not find $input. Saving to list for later."),
          backgroundColor: Colors.yellow,
        ),
      );

      setState(() {
        _isLoading = false;
      });

      return;
    }

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  buildResultList() {
    return ListView.separated(
      itemBuilder: (_, index) {
        final item = _results[index];
        final links = item.links;
        final link = links.length > 0 ? links[0] : null;

        if (link == null) {
          return null;
        }

        return buildResultItem(item, link, index);
      },
      separatorBuilder: (_, index) {
        return Divider(height: 5);
      },
      itemCount: _results.length,
    );
  }

  buildResultItem(LibgenResult item, String link, int index) {
    return Container(
      padding: const EdgeInsets.only(left: 20.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Text(
                item.title,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),
          if (_currentDownload == index)
            Container(
              height: 50,
              padding: const EdgeInsets.only(
                left: 7.0,
              ),
              child: CircularPercentIndicator(
                radius: 40,
                lineWidth: 2,
                percent: _percentDownloaded,
                center: Text("${(_percentDownloaded * 100).floor()}%"),
                progressColor: Colors.green,
              ),
            ),
          if (_currentDownload != index)
            Container(
              height: 50,
              margin: const EdgeInsets.only(
                left: 2.0,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_downward),
                onPressed: () async {
                  setState(() {
                    _currentDownload = index;
                  });

                  final url = await Libgen().extractSecondLevelLink(link);

                  if (url == '') {
                    Scaffold.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to parse URL.")),
                    );
                  }

                  final dio = Dio();
                  final dir = await getTemporaryDirectory();
                  final title = item.title.replaceAll(" ", "");
                  final path = "${dir.path}/$title.epub";
                  print("Writing to $path");

                  try {
                    dio.download(
                      url,
                      path,
                      onReceiveProgress: (actual, total) {
                        final percent = actual / total;
                        if (percent < 1.0) {
                          setState(() {
                            _percentDownloaded = percent;
                          });
                        } else {
                          resetDownload();
                        }
                      },
                    );
                  } catch (e) {
                    Scaffold.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to download file. Please try again")));
                    resetDownload();
                    return;
                  }

                  OpenFile.open(path);
                },
              ),
            ),
        ],
      ),
    );
  }

  resetDownload() {
    setState(() {
      _percentDownloaded = 0.0;
      _currentDownload = -1;
    });
  }

  buildLoadingState() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: SpinKitWanderingCubes(
        color: Colors.blue,
      ),
    );
  }

  void _handlePageNav(int value) {
    setState(() {
      _pageIndex = value;
    });
  }

  buildNotYetDownloadedPage() {
    final items = box.keys.toList();

    return ListView.separated(
      itemBuilder: (_, index) {
        final item = items[index];

        return Dismissible(
          key: Key(item),
          child: InkWell(
            onTap: () {
              performSearch(item);
              setState(() {
                _pageIndex = 0;
                _isLoading = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(5.0),
              child: Text(item),
            ),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            box.delete(item);

            Scaffold.of(context).showSnackBar(
              SnackBar(
                content: Text("Remove $item"),
                backgroundColor: Colors.red,
              ),
            );
          },
          background: Container(
            color: Colors.red,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: 8,
                  ),
                  child: Icon(Icons.delete_forever),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, index) {
        return Divider(height: 5);
      },
      itemCount: items.length,
    );
  }
}
