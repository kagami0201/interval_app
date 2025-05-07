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

class _TrainingScreenState extends State<TrainingScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
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
    
    // アニメーションコントローラーの初期化
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _startExercise();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _notificationService.cancelAllNotifications();
    _audioPlayer.dispose();
    _animationController.dispose();
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
            if (_currentExerciseIndex == widget.exercises.length - 1 && 
                _currentSet == widget.exercises[_currentExerciseIndex].sets) {
              _nextSet();
            } else {
              _startRest();
            }
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

  void _moveToExercise(int index) {
    if (index == _currentExerciseIndex) return; // 現在の種目は何もしない
    
    setState(() {
      _currentExerciseIndex = index;
      _currentSet = 1;
      _isWorkTime = true;
      _remainingTime = widget.exercises[index].workTime;
      _timer?.cancel();
      _startTimer();
    });
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 種目名
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      currentExercise.name,
                      key: ValueKey(currentExercise.name),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // セット数
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'セット $_currentSet / ${currentExercise.sets}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 時間表示
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_isWorkTime),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isWorkTime 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _isWorkTime ? '実施時間' : '休息時間',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 残り時間
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Text(
                      '$_remainingTime 秒',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isWorkTime 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 時間調整ボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeAdjustButton(
                        icon: Icons.add,
                        label: '+10秒',
                        color: Theme.of(context).colorScheme.secondary,
                        onPressed: () {
                          setState(() {
                            _remainingTime += 10;
                            _animationController.forward().then((_) => _animationController.reverse());
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildTimeAdjustButton(
                        icon: Icons.skip_next,
                        label: '-10秒',
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () {
                          setState(() {
                            if (_remainingTime > 10) {
                              _remainingTime -= 10;
                            } else {
                              _remainingTime = 0;
                            }
                            _animationController.forward().then((_) => _animationController.reverse());
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 種目リスト（下部）
          Expanded(
            flex: 2,
            child: Container(
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

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentExercise
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12.0),
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
                            onTap: () {
                              if (!isCompleted) {
                                _moveToExercise(index);
                              }
                            },
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

  Widget _buildTimeAdjustButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
} 