class OutputModel {
  final String text;
  final int? durationMinutes;
  final DateTime timestamp;

  OutputModel({
    required this.text,
    this.durationMinutes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'durationMinutes': durationMinutes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OutputModel.fromJson(Map<String, dynamic> json) {
    return OutputModel(
      text: json['text'] as String,
      durationMinutes: json['durationMinutes'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
