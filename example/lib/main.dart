import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _textController = new TextEditingController();
  final _storage = new FlutterSecureStorage();

  Future read() async {
    String value = await _storage.read(key: "my_key");
    _textController.text = value;
  }

  Future write() async {
    _storage.write(key: "my_key", value: _textController.text);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Plugin example app'),
        ),
        body: new Center(
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Container(
                width: 100.0,
                child: new TextField(
                  controller: _textController,
                ),
              ),
              new ButtonBar(
                children: <Widget>[
                  new FlatButton(
                      onPressed: () => read(), child: new Text("Read")),
                  new FlatButton(
                      onPressed: () => write(), child: new Text("Write")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
