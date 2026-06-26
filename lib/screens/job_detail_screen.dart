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
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobsProvider>().fetchJobDetail(widget.jobId);
    });
  }

  Future<void> _downloadPdf(Job job) async {
    setState(() => _isDownloading = true);
    try {
      await context.read<JobsProvider>().downloadNotificationPdf(job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _applyNow(Job job) async {
    if (job.applyUrl != null && job.applyUrl!.isNotEmpty) {
      final uri = Uri.parse(job.applyUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _shareJob(Job job) {
    Share.share(
      '${job.title}\n${job.organization}\nLast Date: ${job.lastDate}\nApply: ${job.applyUrl ?? "Check TS Jobs App"}',
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
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge
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
                              job.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE91E63),
                              ),
                            ),
                          ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Important Dates
                    _buildSection(
                      title: 'Important Dates',
                      icon: Icons.calendar_today_rounded,
                      child: Column(
                        children: [
                          _buildDateRow(
                            'Application Start',
                            job.applyStartDate,
                            Colors.green,
                            Icons.play_circle_filled_rounded,
                          ),
                          const Divider(height: 20),
                          _buildDateRow(
                            'Application End',
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

                    // Vacancy Details
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
                          if (job.vacancyBreakdown != null) ...[
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
                    const SizedBox(height: 10),

                    // Eligibility
                    _buildSection(
                      title: 'Eligibility',
                      icon: Icons.verified_rounded,
                      child: Column(
                        children: [
                          _buildInfoRow('Age Limit', job.ageLimit ?? 'N/A'),
                          const SizedBox(height: 10),
                          _buildInfoRow(
                            'Qualification',
                            job.qualification ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Fee Section
                    _buildSection(
                      title: 'Application Fee',
                      icon: Icons.payments_rounded,
                      child: Column(
                        children: [
                          if (job.feeDetails != null)
                            ...job.feeDetails!.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildInfoRow(entry.key, entry.value),
                              );
                            })
                          else
                            _buildInfoRow('Fee', job.fee ?? 'N/A'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Selection Process
                    _buildSection(
                      title: 'Selection Process',
                      icon: Icons.format_list_numbered_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (job.selectionProcess != null &&
                              job.selectionProcess!.isNotEmpty)
                            ...job.selectionProcess!.asMap().entries.map(
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
                            )
                          else
                            Text(
                              'Details will be updated',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
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
                  // Download PDF Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isDownloading ? null : () => _downloadPdf(job),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE91E63),
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _isDownloading ? 'Downloading...' : 'Download PDF',
                        style: const TextStyle(
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
                      onPressed: () => _applyNow(job),
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
    String date,
    Color color,
    IconData icon, {
    String? countdown,
  }) {
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
                date,
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
}
