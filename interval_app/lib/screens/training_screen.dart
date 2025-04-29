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
    );
  }
} 