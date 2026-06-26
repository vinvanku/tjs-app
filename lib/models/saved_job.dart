import 'package:intl/intl.dart';

/// Status of a saved/bookmarked job.
enum SavedJobStatus {
  saved,
  applied,
  rejected,
  selected;

  /// Creates a [SavedJobStatus] from a string value.
  static SavedJobStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'applied':
        return SavedJobStatus.applied;
      case 'rejected':
        return SavedJobStatus.rejected;
      case 'selected':
        return SavedJobStatus.selected;
      default:
        return SavedJobStatus.saved;
    }
  }

  /// Display label for UI.
  String get label {
    switch (this) {
      case SavedJobStatus.saved:
        return 'Saved';
      case SavedJobStatus.applied:
        return 'Applied';
      case SavedJobStatus.rejected:
        return 'Rejected';
      case SavedJobStatus.selected:
        return 'Selected';
    }
  }

  /// String value for database storage.
  String get value {
    switch (this) {
      case SavedJobStatus.saved:
        return 'saved';
      case SavedJobStatus.applied:
        return 'applied';
      case SavedJobStatus.rejected:
        return 'rejected';
      case SavedJobStatus.selected:
        return 'selected';
    }
  }
}

/// Represents a job saved/bookmarked by a user.
class SavedJob {
  final String id;
  final String userId;
  final String jobId;
  final SavedJobStatus status;
  final String? notes;
  final DateTime createdAt;

  const SavedJob({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  /// Formatted creation date string.
  String get formattedDate {
    return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
  }

  /// How long ago this was saved (e.g., "2 days ago").
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }

  /// Creates a [SavedJob] from a JSON map (typically from Supabase response).
  factory SavedJob.fromJson(Map<String, dynamic> json) {
    return SavedJob(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      jobId: json['job_id'] as String,
      status: SavedJobStatus.fromString(json['status'] as String? ?? 'saved'),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the [SavedJob] to a JSON map for Supabase insert/update.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'job_id': jobId,
      'status': status.value,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy with the given fields replaced.
  SavedJob copyWith({
    String? id,
    String? userId,
    String? jobId,
    SavedJobStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavedJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedJob && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SavedJob(id: $id, jobId: $jobId, status: ${status.label})';
}
