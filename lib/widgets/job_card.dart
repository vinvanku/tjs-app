import 'package:flutter/material.dart';
import 'countdown_badge.dart';

/// Model representing a job listing.
class Job {
  final String id;
  final String title;
  final String organization;
  final int vacancies;
  final String category;
  final DateTime lastDate;
  final String? source;
  final String? applyUrl;
  final bool isFree;
  final String? qualification;
  final String? district;
  final bool isSaved;

  const Job({
    required this.id,
    required this.title,
    required this.organization,
    required this.vacancies,
    required this.category,
    required this.lastDate,
    this.source,
    this.applyUrl,
    this.isFree = false,
    this.qualification,
    this.district,
    this.isSaved = false,
  });
}

/// A card widget displaying a job listing with title, organization,
/// vacancy/category chips, countdown badge, and bookmark action.
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final VoidCallback? onSave;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Title + Bookmark
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Organization
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.organization,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bookmark button
                  _BookmarkButton(
                    isSaved: job.isSaved,
                    onTap: onSave,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom row: Chips + Countdown
              Row(
                children: [
                  // Vacancy chip
                  _InfoChip(
                    label: '${job.vacancies} Posts',
                    backgroundColor: const Color(0xFFE3F2FD),
                    textColor: const Color(0xFF1565C0),
                    icon: Icons.people_outline,
                  ),
                  const SizedBox(width: 8),
                  // Category chip
                  _InfoChip(
                    label: job.category.toUpperCase(),
                    backgroundColor: const Color(0xFFF3E5F5),
                    textColor: const Color(0xFF7B1FA2),
                  ),
                  // Free badge (if applicable)
                  if (job.isFree) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: 'FREE',
                      backgroundColor: const Color(0xFFE8F5E9),
                      textColor: const Color(0xFF2E7D32),
                    ),
                  ],
                  const Spacer(),
                  // Countdown badge
                  CountdownBadge(targetDate: job.lastDate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal widget for the bookmark icon button.
class _BookmarkButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback? onTap;

  const _BookmarkButton({
    required this.isSaved,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 22,
            color: isSaved ? const Color(0xFFE91E63) : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

/// Internal chip widget for displaying vacancy count and category.
class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
