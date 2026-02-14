import 'output_model.dart';

class DayModel {
  final DateTime date;
  final int scrollTimeMinutes;
  final List<OutputModel> outputs;

  DayModel({
    required this.date,
    required this.scrollTimeMinutes,
    required this.outputs,
  });

  int get outputTimeMinutes {
    return outputs.fold(
      0,
      (sum, output) => sum + (output.durationMinutes ?? 0),
    );
  }

  int get realityGap {
    return scrollTimeMinutes - outputTimeMinutes;
  }

  String get dateKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'scrollTimeMinutes': scrollTimeMinutes,
      'outputs': outputs.map((o) => o.toJson()).toList(),
    };
  }

  factory DayModel.fromJson(Map<String, dynamic> json) {
    return DayModel(
      date: DateTime.parse(json['date'] as String),
      scrollTimeMinutes: json['scrollTimeMinutes'] as int,
      outputs: (json['outputs'] as List<dynamic>)
          .map((o) => OutputModel.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  DayModel copyWith({
    DateTime? date,
    int? scrollTimeMinutes,
    List<OutputModel>? outputs,
  }) {
    return DayModel(
      date: date ?? this.date,
      scrollTimeMinutes: scrollTimeMinutes ?? this.scrollTimeMinutes,
      outputs: outputs ?? this.outputs,
    );
  }
}
