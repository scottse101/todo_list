import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Liste',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  TodoListScreenState createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<TodoList> _lists = [];
  TodoList? _currentList;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/todo_lists.json');
  }

  Future<void> _loadLists() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        setState(() {
          _lists.clear();
          _lists.addAll(
            jsonList.map((item) => TodoList.fromJson(item)).toList(),
          );
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveLists() async {
    final file = await _localFile;
    final jsonList = _lists.map((list) => list.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  void _deleteList(TodoList list) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Slett liste'),
            content: Text('Er du sikker på at du vil slette "${list.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_currentList == list) {
                      _currentList = null;
                    }
                    _lists.remove(list);
                    _saveLists();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Slett', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );
    }

  void _addNewList() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ny Liste'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(hintText: 'Liste navn'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _textController.clear();
              },
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  setState(() {
                    _lists.add(TodoList(name: _textController.text));
                    _saveLists();
                  });
                  Navigator.pop(context);
                  _textController.clear();
                }
              },
              child: const Text('Legg til'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Todo Liste'),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _lists.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onLongPress: () => _deleteList(_lists[index]),
                        borderRadius: BorderRadius.circular(16),
                        child: ChoiceChip(
                          label: Text(_lists[index].name),
                          selected: _currentList == _lists[index],
                          onSelected: (selected) {
                            setState(() {
                              _currentList = selected ? _lists[index] : null;
                              _textController.clear();
                              if (selected) {
                                _showKeyboard(context);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_currentList != null) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () => _showKeyboard(context),
                  child: TextField(
                    controller: _textController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      hintText: 'Legg til nytt element',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          final currentIndex = _lists.indexOf(_currentList!);
                          if (currentIndex != -1) {
                            _lists[currentIndex].items.add(TodoItem(text: value));
                            _saveLists();
                            _textController.clear();
                            // Vis tastaturet igjen etter innsending
                            _showKeyboard(context);
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _currentList!.items.removeAt(oldIndex);
                      _currentList!.items.insert(newIndex, item);
                      _saveLists();
                    });
                  },
                  children: [
                    for (var i = 0; i < _currentList!.items.length; i++)
                      ListTile(
                        key: ValueKey(_currentList!.items[i].text),
                        title: Text(
                          _currentList!.items[i].text,
                          style: TextStyle(
                            decoration: _currentList!.items[i].isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        leading: Checkbox(
                          value: _currentList!.items[i].isCompleted,
                          onChanged: (bool? value) {
                            setState(() {
                              _currentList!.items[i].isCompleted = value!;
                              _saveLists();
                            });
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _currentList!.items.removeAt(i);
                              _saveLists();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewList,
          child: const Icon(Icons.add),
        ),
      );
  }
}

class TodoList {
  String name;
  List<TodoItem> items;

  TodoList({
    required this.name,
    this.items = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory TodoList.fromJson(Map<String, dynamic> json) {
    return TodoList(
      name: json['name'],
      items: (json['items'] as List)
          .map((item) => TodoItem.fromJson(item))
          .toList(),
    );
  }
}

class TodoItem {
  String text;
  bool isCompleted;

  TodoItem({
    required this.text,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCompleted': isCompleted,
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      text: json['text'],
      isCompleted: json['isCompleted'],
    );
  }
}