import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path/path.dart';
// ignore: unnecessary_import
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> insertTask(Task task, Future<Database> database) async {
  final db = await database;

  final List<Map<String, dynamic>> lastTask =
      await db.rawQuery('SELECT * FROM task ORDER BY id DESC LIMIT 1');

  Map<String, dynamic> newTask;

  try {
    newTask = Map<String, dynamic>.from({
      'id': lastTask[0]['id'] + 1,
      'label': task.label,
      'datetime': task.datetime,
      'done': task.done,
    });
  } catch (e) {
    newTask = Map<String, dynamic>.from({
      'id': 1,
      'label': task.label,
      'datetime': task.datetime,
      'done': task.done,
    });
  }

  await db.insert(
    'task',
    newTask,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> markTaskAsDone(int id, Future<Database> database) async {
  final db = await database;

  await db.rawQuery('UPDATE task SET done = 1');
}

Future<void> deleteTask(int id, Future<Database> database) async {
  final db = await database;

  await db.rawQuery("DELETE FROM task WHERE id = '$id'");
}

Future<List<Task>> tasks(Future<Database> database) async {
  final db = await database;

  final List<Map<String, dynamic>> maps = await db.query('task');

  return List.generate(maps.length, (i) {
    return Task(
      id: maps[i]['id'],
      label: maps[i]['label'],
      datetime: maps[i]['datetime'],
      done: maps[i]['done'],
    );
  });
}

Future<List<Task>> doneTasks(Future<Database> database) async {
  final db = await database;

  final List<Map<String, dynamic>> maps =
      await db.rawQuery('SELECT * FROM task WHERE done = 1');

  return List.generate(maps.length, (i) {
    return Task(
      id: maps[i]['id'],
      label: maps[i]['label'],
      datetime: maps[i]['datetime'],
      done: maps[i]['done'],
    );
  });
}

Future<List<Task>> unDoneTasks(Future<Database> database) async {
  final db = await database;

  final List<Map<String, dynamic>> maps =
      await db.rawQuery('SELECT * FROM task WHERE done = 0');

  return List.generate(maps.length, (i) {
    return Task(
      id: maps[i]['id'],
      label: maps[i]['label'],
      datetime: maps[i]['datetime'],
      done: maps[i]['done'],
    );
  });
}

void printAllTasks(Future<Database> database) {
  tasks(database).then((tasks) {
    for (var task in tasks) {
      debugPrint("$task\n");
    }
  }).onError((error, stackTrace) {
    debugPrint("Can't get tasks!");
  });
}

class MyApp extends StatelessWidget {
  final Future<Database> database;
  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Main(database: database),
    );
  }
}

class Task {
  int id;
  final String label;
  final int done;
  final String datetime;

  Task({
    required this.id,
    required this.label,
    required this.done,
    required this.datetime,
  });

  set taskId(int newId) {
    id = newId;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'datetime': datetime,
      'done': done,
    };
  }

  @override
  String toString() {
    return 'Task{id: $id, label: $label, datetime: $datetime, done: $done}';
  }
}

// Form
class TaskRegisterForm extends StatefulWidget {
  final Future<Database> database;
  const TaskRegisterForm({super.key, required this.database});

  @override
  TaskRegisterFormState createState() {
    return TaskRegisterFormState();
  }
}

class TaskRegisterFormState extends State<TaskRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Row(
              children: [
                const Text("Label: "),
                Flexible(
                  child: TextFormField(
                    controller: _labelController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter some text';
                      }
                      return null;
                    },
                  ),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    var taskCreated = Task(
                      label: _labelController.text,
                      datetime: DateTime.now().toString(),
                      done: 0,
                      id: 2,
                    );
                    insertTask(taskCreated, widget.database).then((value) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Task saved successfully!'),
                      ));
                    }).onError((error, stackTrace) {
                      debugPrint("$error\n");
                      debugPrint("$stackTrace\n");
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('An error occured!'),
                      ));
                    });

                    _labelController.clear();
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DoneTaskListView extends StatefulWidget {
  final Future<Database> database;
  const DoneTaskListView({super.key, required this.database});

  @override
  State<DoneTaskListView> createState() => _DoneTaskListViewState();
}

class _DoneTaskListViewState extends State<DoneTaskListView> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: doneTasks(widget.database),
      builder: (BuildContext context, AsyncSnapshot<List<Task>> snapshot) {
        if (snapshot.hasData) {
          List<Task>? allTasks = snapshot.data;
          return allTasks != null
              ? ListView.builder(
                  itemCount: allTasks.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      margin: const EdgeInsets.all(5),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Wrap(
                                  runAlignment: WrapAlignment.start,
                                  children: [
                                    Text(allTasks[index].label),
                                  ],
                                ),
                                Text(
                                  allTasks[index].datetime,
                                  style: const TextStyle(fontSize: 6),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                const IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    deleteTask(
                                            allTasks[index].id, widget.database)
                                        .then((value) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Task deleted successfully!'),
                                      ));
                                      setState(() {});
                                    }).onError((error, stackTrace) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Can\'t delete this task!'),
                                      ));
                                      setState(() {});
                                    });
                                  },
                                ),
                                allTasks[index].done == 0
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.done,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          markTaskAsDone(allTasks[index].id,
                                                  widget.database)
                                              .then((value) {
                                            setState(() {});
                                          });
                                        },
                                      )
                                    : const Text(""),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  })
              : const Center(
                  child: Text("No task"),
                );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}

class UnDoneTaskListView extends StatefulWidget {
  final Future<Database> database;
  const UnDoneTaskListView({super.key, required this.database});

  @override
  State<UnDoneTaskListView> createState() => _UnDoneTaskListViewState();
}

class _UnDoneTaskListViewState extends State<UnDoneTaskListView> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: unDoneTasks(widget.database),
      builder: (BuildContext context, AsyncSnapshot<List<Task>> snapshot) {
        if (snapshot.hasData) {
          List<Task>? allTasks = snapshot.data;
          return allTasks != null
              ? ListView.builder(
                  itemCount: allTasks.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      margin: const EdgeInsets.all(5),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Wrap(
                                  runAlignment: WrapAlignment.start,
                                  children: [
                                    Text(allTasks[index].label),
                                  ],
                                ),
                                Text(
                                  allTasks[index].datetime,
                                  style: const TextStyle(fontSize: 6),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                const IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    deleteTask(
                                            allTasks[index].id, widget.database)
                                        .then((value) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Task deleted successfully!'),
                                      ));
                                      setState(() {});
                                    }).onError((error, stackTrace) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Can\'t delete this task!'),
                                      ));
                                      setState(() {});
                                    });
                                  },
                                ),
                                allTasks[index].done == 0
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.done,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          markTaskAsDone(allTasks[index].id,
                                                  widget.database)
                                              .then((value) {
                                            setState(() {});
                                          });
                                        },
                                      )
                                    : const Text(""),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  })
              : const Center(
                  child: Text("No task"),
                );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}

class AllTaskCustomListView extends StatefulWidget {
  final Future<Database> database;

  const AllTaskCustomListView({super.key, required this.database});

  @override
  State<AllTaskCustomListView> createState() => AllTaskCustomListViewState();
}

class AllTaskCustomListViewState extends State<AllTaskCustomListView> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: tasks(widget.database),
      builder: (BuildContext context, AsyncSnapshot<List<Task>> snapshot) {
        if (snapshot.hasData) {
          List<Task>? allTasks = snapshot.data;
          return allTasks != null
              ? ListView.builder(
                  itemCount: allTasks.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      margin: const EdgeInsets.all(5),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Wrap(
                                  runAlignment: WrapAlignment.start,
                                  children: [
                                    Text(allTasks[index].label),
                                  ],
                                ),
                                Text(
                                  allTasks[index].datetime,
                                  style: const TextStyle(fontSize: 6),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                const IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    deleteTask(
                                            allTasks[index].id, widget.database)
                                        .then((value) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Task deleted successfully!'),
                                      ));
                                      setState(() {});
                                    }).onError((error, stackTrace) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Can\'t delete this task!'),
                                      ));
                                      setState(() {});
                                    });
                                  },
                                ),
                                allTasks[index].done == 0
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.done,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          markTaskAsDone(allTasks[index].id,
                                                  widget.database)
                                              .then((value) {
                                            setState(() {});
                                          });
                                        },
                                      )
                                    : const Text(""),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  })
              : const Center(
                  child: Text("No task"),
                );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}

class Main extends StatefulWidget {
  final Future<Database> database;
  const Main({super.key, required this.database});

  @override
  MainState createState() {
    return MainState();
  }
}

class MainState extends State<Main> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

  late final List<Task> tasks;
  final List<int> colorCodes = <int>[600, 500, 100];

  static List<Widget> _widgetOptions(Future<Database> database) {
    return <Widget>[
      Column(
        children: [
          const Text(
            'Let\'s add new task',
            style: optionStyle,
          ),
          TaskRegisterForm(
            database: database,
          ),
        ],
      ),
      UnDoneTaskListView(database: database),
      DoneTaskListView(database: database),
      AllTaskCustomListView(database: database),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Todo',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: _widgetOptions(widget.database).elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.app_registration),
            label: 'Save',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.charging_station_outlined),
            label: 'In progress',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.done),
            label: 'Done',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.all_inbox),
            label: 'All',
            backgroundColor: Colors.blue,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        onTap: _onItemTapped,
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Future<Database> database = openDatabase(
    join(await getDatabasesPath(), 'task_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE task(id INTEGER PRIMARY KEY AUTOINCREMENT, datetime TEXT, label TEXT, done INTEGER)',
      );
    },
    version: 1,
  );

  runApp(MyApp(database: database));
}
