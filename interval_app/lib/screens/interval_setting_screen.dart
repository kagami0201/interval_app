import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import 'training_screen.dart';

class IntervalSettingScreen extends StatefulWidget {
  const IntervalSettingScreen({super.key});

  @override
  State<IntervalSettingScreen> createState() => _IntervalSettingScreenState();
}

class _IntervalSettingScreenState extends State<IntervalSettingScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Exercise> _exercises = [];
  List<Exercise> _selectedExercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await _databaseService.getExercises();
    setState(() {
      _exercises = exercises;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedExercises.removeAt(oldIndex);
      _selectedExercises.insert(newIndex, item);
    });
  }

  void _addExercise(Exercise exercise) {
    setState(() {
      _selectedExercises.add(exercise);
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
    });
  }

  void _startTraining() {
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を選択してください')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingScreen(exercises: _selectedExercises),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('インターバル設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 登録済み種目リスト
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            '登録済み種目',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                                trailing: IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _addExercise(exercise),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 選択済み種目リスト
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            '選択済み種目',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ReorderableListView.builder(
                            itemCount: _selectedExercises.length,
                            onReorder: _onReorder,
                            itemBuilder: (context, index) {
                              final exercise = _selectedExercises[index];
                              return ListTile(
                                key: ValueKey(exercise),
                                title: Text(exercise.name),
                                subtitle: Text(
                                  '実施: ${exercise.workTime}秒 休息: ${exercise.restTime}秒 セット: ${exercise.sets}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => _removeExercise(index),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _startTraining,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('トレーニング開始'),
            ),
          ),
        ],
      ),
    );
  }
} 