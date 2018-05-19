import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:english_words/english_words.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(new MaterialApp(home: new ItemsWidget()));
}

class ItemsWidget extends StatefulWidget {
  @override
  _ItemsWidgetState createState() => new _ItemsWidgetState();
}

enum _Actions { deleteAll }

class _ItemsWidgetState extends State<ItemsWidget> {
  final _storage = new FlutterSecureStorage();

  List<_SecItem> _items = [];

  @override
  void initState() {
    super.initState();

    _readAll();
  }

  Future<Null> _readAll() async {
    final all = await _storage.readAll();
    setState(() {
      return _items = all.keys
          .map((key) => new _SecItem(key, all[key]))
          .toList(growable: false);
    });
  }

  void _deleteAll() async {
    await _storage.deleteAll();
    _readAll();
  }

  void _addNewItem() async {
    final String key = new Uuid().v4();
    final String value = generateWordPairs().take(5).join(' ');

    await _storage.write(key: key, value: value);
    _readAll();
  }

  @override
  Widget build(BuildContext context) => new Scaffold(
        appBar: new AppBar(
          title: new Text('Plugin example app'),
          actions: <Widget>[
            new IconButton(onPressed: _addNewItem, icon: new Icon(Icons.add)),
            new PopupMenuButton<_Actions>(
                onSelected: (action) {
                  switch (action) {
                    case _Actions.deleteAll:
                      _deleteAll();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_Actions>>[
                      new PopupMenuItem(
                        value: _Actions.deleteAll,
                        child: new Text('Delete all'),
                      ),
                    ])
          ],
        ),
        body: new ListView.builder(
          itemCount: _items.length,
          itemBuilder: (BuildContext context, int index) => new ListTile(
                title: new Text(_items[index].value),
                subtitle: new Text(_items[index].key),
              ),
        ),
      );
}

class _SecItem {
  final String key;
  final String value;

  _SecItem(this.key, this.value);
}
