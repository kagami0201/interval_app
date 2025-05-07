import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/exercise.dart';
import '../services/database_service.dart';
import 'training_screen.dart';
import '../services/admob_service.dart';

class IntervalSettingScreen extends StatefulWidget {
  const IntervalSettingScreen({super.key});

  @override
  State<IntervalSettingScreen> createState() => _IntervalSettingScreenState();
}

class _IntervalSettingScreenState extends State<IntervalSettingScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Exercise> _exercises = [];
  List<Exercise> _selectedExercises = [];
  static const String _selectedExercisesKey = 'selected_exercises';

  @override
  void initState() {
    super.initState();
    _loadExercises();
    AdmobService().loadInterstitialAd();
  }

  Future<void> _loadExercises() async {
    final exercises = await _databaseService.getExercises();
    final prefs = await SharedPreferences.getInstance();
    final orderJson = prefs.getStringList('exercise_order');
    
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
    _loadSelectedExercises();
  }

  Future<void> _loadSelectedExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedExercisesJson = prefs.getStringList(_selectedExercisesKey);
    if (selectedExercisesJson != null) {
      final selectedExercises = selectedExercisesJson
          .map((json) => Exercise.fromMap(jsonDecode(json)))
          .toList();
      setState(() {
        _selectedExercises = selectedExercises;
      });
    }
  }

  Future<void> _saveSelectedExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedExercisesJson = _selectedExercises
        .map((exercise) => jsonEncode(exercise.toMap()))
        .toList();
    await prefs.setStringList(_selectedExercisesKey, selectedExercisesJson);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedExercises.removeAt(oldIndex);
      _selectedExercises.insert(newIndex, item);
    });
    _saveSelectedExercises();
  }

  void _addExercise(Exercise exercise) {
    setState(() {
      _selectedExercises.add(exercise);
    });
    _saveSelectedExercises();
  }

  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
    });
    _saveSelectedExercises();
  }

  void _startTraining() {
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を選択してください')),
      );
      return;
    }
    AdmobService().showInterstitialAd(onAdClosed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrainingScreen(exercises: _selectedExercises),
        ),
      );
    });
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
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: ListTile(
                            title: Text(
                              exercise.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoChip('実施', '${exercise.workTime}秒'),
                                _buildInfoChip('休息', '${exercise.restTime}秒'),
                                _buildInfoChip('セット', '${exercise.sets}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _addExercise(exercise),
                            ),
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
                        return Card(
                          key: ValueKey('${exercise.id}_${index}'),
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle),
                            title: Text(
                              exercise.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoChip('実施', '${exercise.workTime}秒'),
                                _buildInfoChip('休息', '${exercise.restTime}秒'),
                                _buildInfoChip('セット', '${exercise.sets}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeExercise(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // トレーニング開始ボタン
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _startTraining,
              icon: const Icon(Icons.play_arrow),
              label: const Text('トレーニング開始'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 