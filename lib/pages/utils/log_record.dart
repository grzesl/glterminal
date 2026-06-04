import 'log_direction.dart';

/// A single log entry shown as one row in the log window (record mode).
class LogRecord {
  final DateTime time;
  final LogDirection direction;
  final String message;

  /// Number of raw bytes for data entries; null for informational/status lines.
  final int? length;

  LogRecord({
    required this.time,
    required this.direction,
    required this.message,
    this.length,
  });

  /// Time formatted as HH:MM:SS.mmm for the time column.
  String get timeText =>
      "${time.hour.toString().padLeft(2, '0')}:"
      "${time.minute.toString().padLeft(2, '0')}:"
      "${time.second.toString().padLeft(2, '0')}."
      "${time.millisecond.toString().padLeft(3, '0')}";

  Map<String, dynamic> toMap() => {
        'ts': time.millisecondsSinceEpoch,
        'dir': direction.index,
        'msg': message,
        'len': length,
      };

  factory LogRecord.fromMap(Map map) => LogRecord(
        time: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
        direction: LogDirection.values[map['dir'] as int],
        message: map['msg'] as String,
        length: map['len'] as int?,
      );
}
