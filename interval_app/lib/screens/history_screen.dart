import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/training_history.dart';
import '../services/database_service.dart';
import '../services/admob_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<TrainingHistory> _history = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<TrainingHistory>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    AdmobService().showInterstitialAd();
    AdmobService().loadInterstitialAd();
  }

  Future<void> _loadHistory() async {
    final history = await _databaseService.getTrainingHistory();
    setState(() {
      _history = history;
      _events = _groupEventsByDate(history);
    });
  }

  Map<DateTime, List<TrainingHistory>> _groupEventsByDate(List<TrainingHistory> history) {
    final Map<DateTime, List<TrainingHistory>> events = {};
    for (final h in history) {
      final date = DateTime.parse(h.date);
      final key = DateTime(date.year, date.month, date.day);
      if (events[key] == null) events[key] = [];
      events[key]!.add(h);
    }
    return events;
  }

  List<TrainingHistory> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Future<void> _deleteHistory(int id) async {
    await _databaseService.deleteTrainingHistory(id);
    await _loadHistory();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours時間${minutes}分${remainingSeconds}秒';
    } else if (minutes > 0) {
      return '$minutes分${remainingSeconds}秒';
    } else {
      return '$remainingSeconds秒';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング履歴'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // カレンダー表示
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            calendarStyle: CalendarStyle(
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(height: 1),
          // 履歴リスト
          Expanded(
            child: _history.isEmpty
                ? const Center(
                    child: Text('履歴がありません'),
                  )
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final history = _history[index];
                      final date = DateTime.parse(history.date);
                      final weekday = ['月', '火', '水', '木', '金', '土', '日'][date.weekday - 1];
                      return Dismissible(
                        key: Key(history.id.toString()),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          _deleteHistory(history.id!);
                        },
                        dismissThresholds: const {
                          DismissDirection.endToStart: 0.5,
                        },
                        movementDuration: const Duration(milliseconds: 300),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${date.year}/${date.month}/${date.day}($weekday)',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                ...history.exercises.map((exercise) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            exercise.name,
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                          Text(
                                            '${exercise.sets}セット',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          '合計時間',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _formatDuration(history.totalTime),
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 