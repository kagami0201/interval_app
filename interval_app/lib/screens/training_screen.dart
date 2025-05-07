import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../models/exercise.dart';
import '../models/training_history.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class TrainingScreen extends StatefulWidget {
  final List<Exercise> exercises;

  const TrainingScreen({
    super.key,
    required this.exercises,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  int _remainingTime = 0;
  bool _isWorkTime = true;
  bool _isPaused = false;
  Timer? _timer;
  int _totalTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startExercise();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _notificationService.cancelAllNotifications();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _showBackgroundNotification();
    } else if (state == AppLifecycleState.resumed) {
      _notificationService.cancelAllNotifications();
      _notificationService.clearBadge();
    }
  }

  void _showBackgroundNotification() {
    final currentExercise = widget.exercises[_currentExerciseIndex];
    _notificationService.showNotification(
      title: 'トレーニング中',
      body: '${currentExercise.name} - セット $_currentSet / ${currentExercise.sets}\n'
          '${_isWorkTime ? '実施' : '休息'}時間: $_remainingTime秒',
      id: 1,
    );
  }

  void _startExercise() {
    setState(() {
      _remainingTime = widget.exercises[_currentExerciseIndex].workTime;
      _isWorkTime = true;
    });
    _startTimer();
  }

  void _startRest() {
    setState(() {
      _remainingTime = widget.exercises[_currentExerciseIndex].restTime;
      _isWorkTime = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
          _totalTime++;
        } else {
          _timer?.cancel();
          if (_isWorkTime) {
            _playSoundAndVibrate(1);
            _startRest();
          } else {
            _playSoundAndVibrate(2);
            _nextSet();
          }
        }
      });
    });
  }

  Future<void> _playSoundAndVibrate(int count) async {
    if (await Vibration.hasVibrator() ?? false) {
      for (int i = 0; i < count; i++) {
        Vibration.vibrate(duration: 500);
        await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  void _nextSet() {
    if (_currentSet < widget.exercises[_currentExerciseIndex].sets) {
      setState(() {
        _currentSet++;
        _startExercise();
      });
    } else {
      _nextExercise();
    }
  }

  void _nextExercise() async {
    if (_currentExerciseIndex < widget.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSet = 1;
        _startExercise();
      });
    } else {
      // トレーニング終了時に履歴を保存
      await _saveHistory();
      Navigator.pop(context);
    }
  }

  Future<void> _saveHistory() async {
    final exercises = widget.exercises.map((e) => ExerciseHistory(
          name: e.name,
          sets: e.sets,
        )).toList();
    final history = TrainingHistory(
      date: DateTime.now().toIso8601String(),
      exercises: exercises,
      totalTime: _totalTime,
    );
    await _databaseService.insertTrainingHistory(history);
  }

  @override
  Widget build(BuildContext context) {
    final currentExercise = widget.exercises[_currentExerciseIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング中'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 現在の種目の詳細表示（上部）
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentExercise.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'セット $_currentSet / ${currentExercise.sets}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _isWorkTime ? '実施時間' : '休息時間',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_remainingTime 秒',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 16),
                  // 時間調整ボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _remainingTime += 10;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('+10秒'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_remainingTime > 10) {
                              _remainingTime -= 10;
                            } else {
                              _remainingTime = 0;
                            }
                          });
                        },
                        icon: const Icon(Icons.skip_next),
                        label: const Text('-10秒'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isPaused = !_isPaused;
                          });
                        },
                        child: Text(_isPaused ? '再開' : '一時停止'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          _timer?.cancel();
                          await _saveHistory();
                          _notificationService.cancelAllNotifications();
                          Navigator.pop(context);
                        },
                        child: const Text('終了'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 全種目リスト（下部）
          Expanded(
            flex: 2,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'トレーニング種目',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = widget.exercises[index];
                        final isCurrentExercise = index == _currentExerciseIndex;
                        final isCompleted = index < _currentExerciseIndex;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentExercise
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isCurrentExercise
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : isCurrentExercise
                                      ? Icons.play_circle_fill
                                      : Icons.radio_button_unchecked,
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrentExercise
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                            ),
                            title: Text(
                              exercise.name,
                              style: TextStyle(
                                fontWeight: isCurrentExercise ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${exercise.workTime}秒 × ${exercise.sets}セット（休息${exercise.restTime}秒）',
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
        ],
      ),
    );
  }
} 