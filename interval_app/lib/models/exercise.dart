class Exercise {
  final int? id;
  final String name;
  final int workTime;
  final int restTime;
  final int sets;

  Exercise({
    this.id,
    required this.name,
    required this.workTime,
    required this.restTime,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'workTime': workTime,
      'restTime': restTime,
      'sets': sets,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      name: map['name'] as String,
      workTime: map['workTime'] as int,
      restTime: map['restTime'] as int,
      sets: map['sets'] as int,
    );
  }
} 