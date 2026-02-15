// models/tracker_slot_model.dart

class TrackerSlotModel {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int intervalMinutes;
  final String? outputText;
  final int? outputDurationMinutes;

  const TrackerSlotModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.intervalMinutes,
    this.outputText,
    this.outputDurationMinutes,
  });

  /// Whether the user has already logged output for this slot.
  bool get isLogged => outputText != null;

  /// Human-readable range, e.g. "10:30 – 11:00"
  String get timeRange {
    String _fmt(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h % 12 == 0 ? 12 : h % 12;
      return '$hour:$m $period';
    }

    return '${_fmt(startTime)} – ${_fmt(endTime)}';
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'intervalMinutes': intervalMinutes,
        'outputText': outputText,
        'outputDurationMinutes': outputDurationMinutes,
      };

  factory TrackerSlotModel.fromJson(Map<String, dynamic> json) =>
      TrackerSlotModel(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        intervalMinutes: json['intervalMinutes'] as int,
        outputText: json['outputText'] as String?,
        outputDurationMinutes: json['outputDurationMinutes'] as int?,
      );

  TrackerSlotModel copyWith({
    String? outputText,
    int? outputDurationMinutes,
  }) =>
      TrackerSlotModel(
        id: id,
        startTime: startTime,
        endTime: endTime,
        intervalMinutes: intervalMinutes,
        outputText: outputText ?? this.outputText,
        outputDurationMinutes:
            outputDurationMinutes ?? this.outputDurationMinutes,
      );
}
