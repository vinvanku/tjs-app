import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/jobs_provider.dart';
import '../models/job_model.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobsProvider>().fetchJobDetail(widget.jobId);
    });
  }

  Future<void> _openSourceUrl(Job job) async {
    // Use source_url (mapped to applyUrl in Job model) as the primary link
    final url = job.applyUrl.isNotEmpty ? job.applyUrl : null;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the link'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No application link available for this job'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _downloadPdf(Job job) async {
    // Use pdfUrl if available, otherwise fall back to source_url (applyUrl)
    final url = (job.pdfUrl != null && job.pdfUrl!.isNotEmpty)
        ? job.pdfUrl!
        : job.applyUrl;
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No PDF/notification link available'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _shareJob(Job job) {
    final url = job.applyUrl.isNotEmpty ? job.applyUrl : 'Check TS Jobs App';
    Share.share(
      '${job.title}\n${job.organization}\nLast Date: ${job.formattedLastDate}\nApply: $url',
      subject: job.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<JobsProvider>(
        builder: (context, jobsProvider, _) {
          final job = jobsProvider.selectedJob;

          if (jobsProvider.isLoadingDetail || job == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE91E63),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                pinned: true,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _shareJob(job),
                    icon: const Icon(
                      Icons.share_outlined,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.read<JobsProvider>().toggleBookmark(job.id);
                    },
                    icon: Icon(
                      job.isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: job.isBookmarked
                          ? const Color(0xFFE91E63)
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section — always show
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge
                          if (job.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                job.category[0].toUpperCase() +
                                    job.category.substring(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE91E63),
                                ),
                              ),
                            ),
                          if (job.category.isNotEmpty)
                            const SizedBox(height: 12),

                          // Title
                          Text(
                            job.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Organization
                          if (job.organization.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_outlined,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    job.organization,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          // Source
                          if (job.source.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Source: ${job.source}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Important Dates — always show last_date
                    _buildSection(
                      title: 'Important Dates',
                      icon: Icons.calendar_today_rounded,
                      child: Column(
                        children: [
                          if (job.applyStartDate != null) ...[
                            _buildDateRow(
                              'Application Start',
                              job.applyStartDate!,
                              Colors.green,
                              Icons.play_circle_filled_rounded,
                            ),
                            const Divider(height: 20),
                          ],
                          _buildDateRow(
                            'Last Date to Apply',
                            job.lastDate,
                            Colors.red,
                            Icons.stop_circle_rounded,
                            countdown: job.daysLeft > 0
                                ? '${job.daysLeft} days left'
                                : 'Closed',
                          ),
                          if (job.examDate != null) ...[
                            const Divider(height: 20),
                            _buildDateRow(
                              'Exam Date',
                              job.examDate!,
                              Colors.blue,
                              Icons.event_rounded,
                            ),
                          ],
                          if (job.resultDate != null) ...[
                            const Divider(height: 20),
                            _buildDateRow(
                              'Result Date',
                              job.resultDate!,
                              Colors.orange,
                              Icons.emoji_events_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Vacancy Details — show only if vacancies > 0
                    if (job.vacancies > 0)
                      _buildSection(
                        title: 'Vacancy Details',
                        icon: Icons.people_rounded,
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Total Vacancies',
                              '${job.vacancies}',
                              isBold: true,
                            ),
                            if (job.vacancyBreakdown != null &&
                                job.vacancyBreakdown!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ...job.vacancyBreakdown!.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildInfoRow(
                                    entry.key,
                                    '${entry.value}',
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    if (job.vacancies > 0) const SizedBox(height: 10),

                    // Eligibility — show only if qualification or ageLimit has data
                    if ((job.qualification.isNotEmpty) ||
                        (job.ageLimit != null && job.ageLimit!.isNotEmpty))
                      _buildSection(
                        title: 'Eligibility',
                        icon: Icons.verified_rounded,
                        child: Column(
                          children: [
                            if (job.ageLimit != null &&
                                job.ageLimit!.isNotEmpty)
                              _buildInfoRow('Age Limit', job.ageLimit!),
                            if (job.ageLimit != null &&
                                job.ageLimit!.isNotEmpty &&
                                job.qualification.isNotEmpty)
                              const SizedBox(height: 10),
                            if (job.qualification.isNotEmpty)
                              _buildInfoRow(
                                'Qualification',
                                job.qualification,
                              ),
                          ],
                        ),
                      ),
                    if ((job.qualification.isNotEmpty) ||
                        (job.ageLimit != null && job.ageLimit!.isNotEmpty))
                      const SizedBox(height: 10),

                    // District — show only if district has meaningful data
                    if (job.district.isNotEmpty &&
                        job.district != 'All Telangana')
                      _buildSection(
                        title: 'Location',
                        icon: Icons.location_on_rounded,
                        child: _buildInfoRow('District', job.district),
                      ),
                    if (job.district.isNotEmpty &&
                        job.district != 'All Telangana')
                      const SizedBox(height: 10),

                    // Fee Section — show only if fee data exists
                    if ((job.feeDetails != null &&
                            job.feeDetails!.isNotEmpty) ||
                        (job.fee != null && job.fee!.isNotEmpty) ||
                        job.feeGeneral > 0)
                      _buildSection(
                        title: 'Application Fee',
                        icon: Icons.payments_rounded,
                        child: Column(
                          children: [
                            if (job.feeDetails != null &&
                                job.feeDetails!.isNotEmpty)
                              ...job.feeDetails!.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildInfoRow(
                                      entry.key, '${entry.value}'),
                                );
                              })
                            else if (job.fee != null && job.fee!.isNotEmpty)
                              _buildInfoRow('Fee', job.fee!)
                            else if (job.feeGeneral > 0) ...[
                              _buildInfoRow(
                                  'General', '₹${job.feeGeneral.toInt()}'),
                              if (job.feeScSt > 0) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                    'SC/ST', '₹${job.feeScSt.toInt()}'),
                              ],
                            ],
                          ],
                        ),
                      ),
                    if ((job.feeDetails != null &&
                            job.feeDetails!.isNotEmpty) ||
                        (job.fee != null && job.fee!.isNotEmpty) ||
                        job.feeGeneral > 0)
                      const SizedBox(height: 10),

                    // Selection Process — show only if data exists
                    if (job.selectionProcess != null &&
                        job.selectionProcess!.isNotEmpty)
                      _buildSection(
                        title: 'Selection Process',
                        icon: Icons.format_list_numbered_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: job.selectionProcess!.asMap().entries.map(
                            (entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE91E63)
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFE91E63),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    if (job.selectionProcess != null &&
                        job.selectionProcess!.isNotEmpty)
                      const SizedBox(height: 10),

                    // Description — show only if non-empty
                    if (job.description.isNotEmpty)
                      _buildSection(
                        title: 'Description',
                        icon: Icons.description_rounded,
                        child: Text(
                          job.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (job.description.isNotEmpty) const SizedBox(height: 10),

                    // Free job badge
                    if (job.isActive)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This job is currently active and accepting applications',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // Bottom Action Buttons
      bottomNavigationBar: Consumer<JobsProvider>(
        builder: (context, jobsProvider, _) {
          final job = jobsProvider.selectedJob;
          if (job == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // View Notification / Download PDF Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadPdf(job),
                      icon:
                          const Icon(Icons.description_rounded, size: 20),
                      label: const Text(
                        'View Notification',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE91E63),
                        side: const BorderSide(color: Color(0xFFE91E63)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Apply Now Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openSourceUrl(job),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Apply Now →',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        shadowColor:
                            const Color(0xFFE91E63).withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFE91E63)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDateRow(
    String label,
    dynamic date,
    Color color,
    IconData icon, {
    String? countdown,
  }) {
    final dateStr = date is DateTime
        ? '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}'
        : date?.toString() ?? 'TBA';
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
        if (countdown != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              countdown,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
