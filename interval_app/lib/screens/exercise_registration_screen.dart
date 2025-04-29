import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';

class ExerciseRegistrationScreen extends StatefulWidget {
  const ExerciseRegistrationScreen({super.key});

  @override
  State<ExerciseRegistrationScreen> createState() => _ExerciseRegistrationScreenState();
}

class _ExerciseRegistrationScreenState extends State<ExerciseRegistrationScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _workTimeController = TextEditingController();
  final _restTimeController = TextEditingController();
  final _setsController = TextEditingController();
  List<Exercise> _exercises = [];
  Exercise? _editingExercise;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workTimeController.dispose();
    _restTimeController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final exercises = await _databaseService.getExercises();
    setState(() {
      _exercises = exercises;
    });
  }

  void _editExercise(Exercise exercise) {
    setState(() {
      _editingExercise = exercise;
      _nameController.text = exercise.name;
      _workTimeController.text = exercise.workTime.toString();
      _restTimeController.text = exercise.restTime.toString();
      _setsController.text = exercise.sets.toString();
    });
  }

  void _deleteExercise(Exercise exercise) async {
    await _databaseService.deleteExercise(exercise.id!);
    _loadExercises();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final exercise = Exercise(
        id: _editingExercise?.id,
        name: _nameController.text,
        workTime: int.parse(_workTimeController.text),
        restTime: int.parse(_restTimeController.text),
        sets: int.parse(_setsController.text),
      );

      if (_editingExercise != null) {
        await _databaseService.updateExercise(exercise);
      } else {
        await _databaseService.insertExercise(exercise);
      }

      setState(() {
        _editingExercise = null;
        _nameController.clear();
        _workTimeController.clear();
        _restTimeController.clear();
        _setsController.clear();
      });

      _loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('種目登録'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(
                    '実施: ${exercise.workTime}秒 休息: ${exercise.restTime}秒 セット: ${exercise.sets}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editExercise(exercise),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteExercise(exercise),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '種目名'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '種目名を入力してください';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _workTimeController,
                    decoration: const InputDecoration(labelText: '実施時間（秒）'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '実施時間を入力してください';
                      }
                      if (int.tryParse(value) == null) {
                        return '数値を入力してください';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _restTimeController,
                    decoration: const InputDecoration(labelText: '休息時間（秒）'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '休息時間を入力してください';
                      }
                      if (int.tryParse(value) == null) {
                        return '数値を入力してください';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _setsController,
                    decoration: const InputDecoration(labelText: 'セット数'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'セット数を入力してください';
                      }
                      if (int.tryParse(value) == null) {
                        return '数値を入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(_editingExercise != null ? '更新' : '登録'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 