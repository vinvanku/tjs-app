import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Status of a job in the user's tracking pipeline.
enum JobStatus { saved, applied, examSoon, shortlisted, rejected, resultOut }

/// Represents a downloaded PDF file.
class DownloadedPdf {
  final String fileName;
  final String filePath;
  final String downloadDate;
  const DownloadedPdf({required this.fileName, required this.filePath, required this.downloadDate});
}

/// Event type for calendar.
enum EventType { lastDate, exam, result }

/// Represents a calendar event derived from job dates.
class CalendarEvent {
  final String jobId;
  final String title;
  final EventType type;
  final DateTime date;
  CalendarEvent({required this.jobId, required this.title, required this.type, required this.date});
}

/// Represents a government job posting in Telangana.
class Job {
  final String id;
  final String title;
  final String organization;
  final String category;
  final int vacancies;
  final DateTime lastDate;
  final DateTime? examDate;
  final String qualification;
  final int ageMin;
  final int ageMax;
  final List<String> districts;
  final double salaryMin;
  final double salaryMax;
  final double feeGeneral;
  final double feeScSt;
  final String applyUrl;
  final String? pdfUrl;
  final String source;
  final bool isActive;
  final bool isFeatured;
  final DateTime postedDate;
  final String description;
  final String district;
  final bool isBookmarked;
  final JobStatus? status;
  final DateTime? applyStartDate;
  final DateTime? resultDate;
  final Map<String, dynamic>? vacancyBreakdown;
  final String? ageLimit;
  final Map<String, dynamic>? feeDetails;
  final String? fee;
  final List<String>? selectionProcess;

  const Job({
    required this.id,
    required this.title,
    required this.organization,
    required this.category,
    required this.vacancies,
    required this.lastDate,
    this.examDate,
    required this.qualification,
    required this.ageMin,
    required this.ageMax,
    required this.districts,
    required this.salaryMin,
    required this.salaryMax,
    required this.feeGeneral,
    required this.feeScSt,
    required this.applyUrl,
    this.pdfUrl,
    required this.source,
    required this.isActive,
    required this.isFeatured,
    required this.postedDate,
    this.description = '',
    this.district = 'All Telangana',
    this.isBookmarked = false,
    this.status,
    this.applyStartDate,
    this.resultDate,
    this.vacancyBreakdown,
    this.ageLimit,
    this.feeDetails,
    this.fee,
    this.selectionProcess,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // COMPUTED GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Number of days remaining until the last date to apply.
  /// Returns 0 if the deadline has passed.
  int get daysLeft {
    final now = DateTime.now();
    final difference = lastDate.difference(now).inDays;
    return difference > 0 ? difference : 0;
  }

  /// Whether the application deadline has passed.
  bool get isExpired {
    return DateTime.now().isAfter(lastDate);
  }

  /// Color indicator based on urgency:
  /// - Red: 0-3 days left (critical)
  /// - Orange: 4-7 days left (warning)
  /// - Amber: 8-14 days left (moderate)
  /// - Green: 15+ days left (safe)
  /// - Grey: expired
  Color get urgencyColor {
    if (isExpired) return Colors.grey;
    if (daysLeft <= 3) return Colors.red.shade700;
    if (daysLeft <= 7) return Colors.deepOrange;
    if (daysLeft <= 14) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  /// Human-readable urgency label.
  String get urgencyLabel {
    if (isExpired) return 'Expired';
    if (daysLeft == 0) return 'Last day!';
    if (daysLeft == 1) return '1 day left';
    if (daysLeft <= 3) return '$daysLeft days left - Hurry!';
    if (daysLeft <= 7) return '$daysLeft days left';
    return '$daysLeft days left';
  }

  /// Formatted salary range string (e.g., "₹25,000 - ₹80,000").
  String get salaryRange {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    if (salaryMin == salaryMax) {
      return '₹${formatter.format(salaryMin)}';
    }
    return '₹${formatter.format(salaryMin)} - ₹${formatter.format(salaryMax)}';
  }

  /// Formatted last date string.
  String get formattedLastDate {
    return DateFormat('dd MMM yyyy').format(lastDate);
  }

  /// Formatted exam date string (or 'TBA' if not set).
  String get formattedExamDate {
    if (examDate == null) return 'TBA';
    return DateFormat('dd MMM yyyy').format(examDate!);
  }

  /// Formatted posted date string.
  String get formattedPostedDate {
    return DateFormat('dd MMM yyyy').format(postedDate);
  }

  /// Districts display (comma-separated or 'All Districts').
  String get districtsDisplay {
    if (districts.isEmpty || districts.contains('All')) {
      return 'All Districts';
    }
    if (districts.length > 3) {
      return '${districts.take(3).join(", ")} +${districts.length - 3} more';
    }
    return districts.join(', ');
  }

  /// Age range display.
  String get ageRange => '$ageMin - $ageMax years';

  // ─────────────────────────────────────────────────────────────────────────
  // SERIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a [Job] from a JSON map (typically from Supabase response).
  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      title: json['title'] as String,
      organization: json['organization'] as String,
      category: json['category'] as String,
      vacancies: json['vacancies'] as int? ?? 0,
      lastDate: DateTime.parse(json['last_date'] as String),
      examDate: json['exam_date'] != null
          ? DateTime.parse(json['exam_date'] as String)
          : null,
      qualification: json['qualification'] as String? ?? '',
      ageMin: json['age_min'] as int? ?? 18,
      ageMax: json['age_max'] as int? ?? 44,
      districts: json['districts'] != null
          ? List<String>.from(json['districts'] as List)
          : <String>[],
      salaryMin: (json['salary_min'] as num?)?.toDouble() ?? 0,
      salaryMax: (json['salary_max'] as num?)?.toDouble() ?? 0,
      feeGeneral: (json['fee_general'] as num?)?.toDouble() ?? 0,
      feeScSt: (json['fee_sc_st'] as num?)?.toDouble() ?? 0,
      applyUrl: json['apply_url'] as String? ?? '',
      pdfUrl: json['pdf_url'] as String?,
      source: json['source'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      postedDate: json['posted_date'] != null
          ? DateTime.parse(json['posted_date'] as String)
          : DateTime.now(),
      description: json['description'] as String? ?? '',
      district: json['district'] as String? ?? 'All Telangana',
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      status: json['status'] != null
          ? JobStatus.values.where((e) => e.name == json['status']).firstOrNull
          : null,
      applyStartDate: json['apply_start_date'] != null
          ? DateTime.parse(json['apply_start_date'] as String)
          : null,
      resultDate: json['result_date'] != null
          ? DateTime.parse(json['result_date'] as String)
          : null,
      vacancyBreakdown: json['vacancy_breakdown'] as Map<String, dynamic>?,
      ageLimit: json['age_limit'] as String?,
      feeDetails: json['fee_details'] as Map<String, dynamic>?,
      fee: json['fee'] as String?,
      selectionProcess: json['selection_process'] != null
          ? List<String>.from(json['selection_process'] as List)
          : null,
    );
  }

  /// Converts the [Job] to a JSON map for storage/API calls.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'organization': organization,
      'category': category,
      'vacancies': vacancies,
      'last_date': lastDate.toIso8601String(),
      'exam_date': examDate?.toIso8601String(),
      'qualification': qualification,
      'age_min': ageMin,
      'age_max': ageMax,
      'districts': districts,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'fee_general': feeGeneral,
      'fee_sc_st': feeScSt,
      'apply_url': applyUrl,
      'pdf_url': pdfUrl,
      'source': source,
      'is_active': isActive,
      'is_featured': isFeatured,
      'posted_date': postedDate.toIso8601String(),
      'description': description,
      'district': district,
      'is_bookmarked': isBookmarked,
      'status': status?.name,
      'apply_start_date': applyStartDate?.toIso8601String(),
      'result_date': resultDate?.toIso8601String(),
      'vacancy_breakdown': vacancyBreakdown,
      'age_limit': ageLimit,
      'fee_details': feeDetails,
      'fee': fee,
      'selection_process': selectionProcess,
    };
  }

  /// Creates a copy of this Job with the given fields replaced.
  Job copyWith({
    String? id,
    String? title,
    String? organization,
    String? category,
    int? vacancies,
    DateTime? lastDate,
    DateTime? examDate,
    String? qualification,
    int? ageMin,
    int? ageMax,
    List<String>? districts,
    double? salaryMin,
    double? salaryMax,
    double? feeGeneral,
    double? feeScSt,
    String? applyUrl,
    String? pdfUrl,
    String? source,
    bool? isActive,
    bool? isFeatured,
    DateTime? postedDate,
    String? description,
    String? district,
    bool? isBookmarked,
    JobStatus? status,
    DateTime? applyStartDate,
    DateTime? resultDate,
    Map<String, dynamic>? vacancyBreakdown,
    String? ageLimit,
    Map<String, dynamic>? feeDetails,
    String? fee,
    List<String>? selectionProcess,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      organization: organization ?? this.organization,
      category: category ?? this.category,
      vacancies: vacancies ?? this.vacancies,
      lastDate: lastDate ?? this.lastDate,
      examDate: examDate ?? this.examDate,
      qualification: qualification ?? this.qualification,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      districts: districts ?? this.districts,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      feeGeneral: feeGeneral ?? this.feeGeneral,
      feeScSt: feeScSt ?? this.feeScSt,
      applyUrl: applyUrl ?? this.applyUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      source: source ?? this.source,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      postedDate: postedDate ?? this.postedDate,
      description: description ?? this.description,
      district: district ?? this.district,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      status: status ?? this.status,
      applyStartDate: applyStartDate ?? this.applyStartDate,
      resultDate: resultDate ?? this.resultDate,
      vacancyBreakdown: vacancyBreakdown ?? this.vacancyBreakdown,
      ageLimit: ageLimit ?? this.ageLimit,
      feeDetails: feeDetails ?? this.feeDetails,
      fee: fee ?? this.fee,
      selectionProcess: selectionProcess ?? this.selectionProcess,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Job && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Job(id: $id, title: $title, org: $organization)';
}
