import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  static const String _exerciseOrderKey = 'exercise_order';

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
    final prefs = await SharedPreferences.getInstance();
    final orderJson = prefs.getStringList(_exerciseOrderKey);
    
    if (orderJson != null) {
      final order = orderJson.map((id) => int.parse(id)).toList();
      exercises.sort((a, b) {
        final aIndex = order.indexOf(a.id!);
        final bIndex = order.indexOf(b.id!);
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;
        return aIndex.compareTo(bIndex);
      });
    }
    
    setState(() {
      _exercises = exercises;
    });
  }

  Future<void> _saveExerciseOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = _exercises.map((e) => e.id.toString()).toList();
    await prefs.setStringList(_exerciseOrderKey, order);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
    _saveExerciseOrder();
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              SizedBox(
                height: 300,
                child: ReorderableListView.builder(
                  itemCount: _exercises.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    return ListTile(
                      key: ValueKey(exercise),
                      title: Text(exercise.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('実施: ${exercise.workTime}秒'),
                          Text('休息: ${exercise.restTime}秒'),
                          Text('セット: ${exercise.sets}'),
                        ],
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
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '種目名',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          counterText: '',
                        ),
                        maxLength: 50,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '種目名を入力してください';
                          }
                          if (value.length > 50) {
                            return '種目名は50文字以内で入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _workTimeController,
                        decoration: const InputDecoration(
                          labelText: '実施時間（秒）',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '実施時間を入力してください';
                          }
                          if (int.tryParse(value) == null) {
                            return '数値を入力してください';
                          }
                          final time = int.parse(value);
                          if (time <= 0) {
                            return '1秒以上を入力してください';
                          }
                          if (time > 999) {
                            return '999秒以内で入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _restTimeController,
                        decoration: const InputDecoration(
                          labelText: '休息時間（秒）',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '休息時間を入力してください';
                          }
                          if (int.tryParse(value) == null) {
                            return '数値を入力してください';
                          }
                          final time = int.parse(value);
                          if (time <= 0) {
                            return '1秒以上を入力してください';
                          }
                          if (time > 999) {
                            return '999秒以内で入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _setsController,
                        decoration: const InputDecoration(
                          labelText: 'セット数',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'セット数を入力してください';
                          }
                          if (int.tryParse(value) == null) {
                            return '数値を入力してください';
                          }
                          final sets = int.parse(value);
                          if (sets <= 0) {
                            return '1セット以上を入力してください';
                          }
                          if (sets > 999) {
                            return '999セット以内で入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: Icon(_editingExercise != null ? Icons.save : Icons.add),
                        label: Text(_editingExercise != null ? '更新' : '登録'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 