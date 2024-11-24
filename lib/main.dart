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
  final FocusNode _focusNode = FocusNode();
  final List<TodoList> _lists = [];
  TodoList? _currentList;

  @override
  void initState() {
    super.initState();
    _loadLists();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentList != null) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
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
                                _focusNode.requestFocus();
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
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Legg til nytt element',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    fillColor: Colors.white,
                    filled: true,
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
                          _focusNode.requestFocus();
                        }
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    overscroll: true,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_currentList!.items.where((item) => !item.isCompleted).isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Ukjøpte varer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ReorderableListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            buildDefaultDragHandles: false,
                            itemCount: _currentList!.items.where((item) => !item.isCompleted).length,
                            itemBuilder: (context, index) {
                              final item = _currentList!.items.where((item) => !item.isCompleted).toList()[index];
                              return ListTile(
                                key: ValueKey(item.text),
                                title: Text(item.text),
                                leading: Checkbox(
                                  value: item.isCompleted,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      item.isCompleted = value!;
                                      _saveLists();
                                    });
                                  },
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_handle),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        setState(() {
                                          _currentList!.items.remove(item);
                                          _saveLists();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                final uncompleted = _currentList!.items
                                    .where((item) => !item.isCompleted)
                                    .toList();
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = uncompleted.removeAt(oldIndex);
                                uncompleted.insert(newIndex, item);

                                final completed = _currentList!.items
                                    .where((item) => item.isCompleted)
                                    .toList();
                                _currentList!.items = [...uncompleted, ...completed];
                                _saveLists();
                              });
                            },
                          ),
                        ],
                        if (_currentList!.items.where((item) => item.isCompleted).isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Kjøpte varer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...(_currentList!.items.where((item) => item.isCompleted)
                              .map((item) => ListTile(
                            key: ValueKey(item.text),
                            title: Text(
                              item.text,
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            leading: Checkbox(
                              value: item.isCompleted,
                              onChanged: (bool? value) {
                                setState(() {
                                  item.isCompleted = value!;
                                  _saveLists();
                                });
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  _currentList!.items.remove(item);
                                  _saveLists();
                                });
                              },
                            ),
                          ))),
                        ],
                      ],
                    ),
                  ),
                ),
              )
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