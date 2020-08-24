import 'package:flutter/material.dart' hide Element;
import 'package:flutter/widgets.dart';
import 'package:reader/libgen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
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
      home: HomePage(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          buildForm(),
          Divider(
            height: 5,
          ),
          if (!_isLoading) Expanded(child: buildResultList()),
          if (_isLoading) buildLoadingState(),
        ],
      ),
    );
  }

  Form buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(20),
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
          ),
          RaisedButton(
            onPressed: () {
              if (_formKey.currentState.validate()) {
                _formKey.currentState.save();
                setState(() {
                  _isLoading = true;
                });
              }
            },
            child: Text("Search"),
          ),
        ],
      ),
    );
  }

  performSearch(String input) async {
    final results = await Libgen().performSearch(input);
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
              if (link != null)
                Container(
                  height: 50,
                  margin: const EdgeInsets.only(left: 2.0,),
                  child: IconButton(
                    icon: Icon(Icons.arrow_downward),
                    onPressed: () async {
                      final url = await Libgen().extractSecondLevelLink(link);
                      if (url == '') {
                        Scaffold.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to parse URL.")),
                        );
                      }

                      launch(url);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      separatorBuilder: (_, index) {
        return Divider(height: 5);
      },
      itemCount: _results.length,
    );
  }

  buildLoadingState() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: SpinKitWanderingCubes(
        color: Colors.grey,
      ),
    );
  }
}
