import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(MaterialApp(home: ItemsWidget()));
}

class ItemsWidget extends StatefulWidget {
  @override
  _ItemsWidgetState createState() => _ItemsWidgetState();
}

enum _Actions { deleteAll }
enum _ItemActions { delete, edit }

class _ItemsWidgetState extends State<ItemsWidget> {
  final _storage = FlutterSecureStorage();

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
          .map((key) => _SecItem(key, all[key]))
          .toList(growable: false);
    });
  }

  void _deleteAll() async {
    await _storage.deleteAll();
    _readAll();
  }

  void _addNewItem() async {
    final String key = _randomValue();
    final String value = _randomValue();

    await _storage.write(key: key, value: value);
    _readAll();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Plugin example app'),
          actions: <Widget>[
            IconButton(
                key: Key('add_random'),
                onPressed: _addNewItem,
                icon: Icon(Icons.add)),
            PopupMenuButton<_Actions>(
                key: Key('popup_menu'),
                onSelected: (action) {
                  switch (action) {
                    case _Actions.deleteAll:
                      _deleteAll();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_Actions>>[
                      PopupMenuItem(
                        key: Key('delete_all'),
                        value: _Actions.deleteAll,
                        child: Text('Delete all'),
                      ),
                    ])
          ],
        ),
        body: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (BuildContext context, int index) => ListTile(
            trailing: PopupMenuButton(
                key: Key('popup_row_$index'),
                onSelected: (_ItemActions action) =>
                    _performAction(action, _items[index]),
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_ItemActions>>[
                      PopupMenuItem(
                        value: _ItemActions.delete,
                        child: Text(
                          'Delete',
                          key: Key('delete_row_$index'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _ItemActions.edit,
                        child: Text(
                          'Edit',
                          key: Key('edit_row_$index'),
                        ),
                      ),
                    ]),
            title: Text(
              _items[index].value,
              key: Key('title_row_$index'),
            ),
            subtitle: Text(
              _items[index].key,
              key: Key('subtitle_row_$index'),
            ),
          ),
        ),
      );

  Future<Null> _performAction(_ItemActions action, _SecItem item) async {
    switch (action) {
      case _ItemActions.delete:
        await _storage.delete(key: item.key);
        _readAll();

        break;
      case _ItemActions.edit:
        final result = await showDialog<String>(
            context: context,
            builder: (context) => _EditItemWidget(item.value));
        if (result != null) {
          await _storage.write(key: item.key, value: result);
          _readAll();
        }
        break;
    }
  }

  String _randomValue() {
    final rand = Random();
    final codeUnits = List.generate(20, (index) {
      return rand.nextInt(26) + 65;
    });

    return String.fromCharCodes(codeUnits);
  }
}

class _EditItemWidget extends StatelessWidget {
  _EditItemWidget(String text)
      : _controller = TextEditingController(text: text);

  final TextEditingController _controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit item'),
      content: TextField(
        key: Key('title_field'),
        controller: _controller,
        autofocus: true,
      ),
      actions: <Widget>[
        FlatButton(
            key: Key('cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel')),
        FlatButton(
            key: Key('save'),
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: Text('Save')),
      ],
    );
  }
}

class _SecItem {
  _SecItem(this.key, this.value);

  final String key;
  final String value;
}
