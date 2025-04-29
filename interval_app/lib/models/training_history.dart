class TrainingHistory {
  final int? id;
  final String date;
  final List<ExerciseHistory> exercises;
  final int totalTime;

  TrainingHistory({
    this.id,
    required this.date,
    required this.exercises,
    required this.totalTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'totalTime': totalTime,
    };
  }

  factory TrainingHistory.fromMap(Map<String, dynamic> map) {
    return TrainingHistory(
      id: map['id'] as int?,
      date: map['date'] as String,
      exercises: (map['exercises'] as List)
          .map((e) => ExerciseHistory.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalTime: map['totalTime'] as int,
    );
  }
}

class ExerciseHistory {
  final String name;
  final int sets;

  ExerciseHistory({
    required this.name,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
    };
  }

  factory ExerciseHistory.fromMap(Map<String, dynamic> map) {
    return ExerciseHistory(
      name: map['name'] as String,
      sets: map['sets'] as int,
    );
  }
} 