import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/jobs_provider.dart';
import '../models/job_model.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobsProvider>().fetchSavedJobs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1A1A2E),
          ),
        ),
        title: const Text(
          'Saved Jobs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFE91E63),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: const Color(0xFFE91E63),
          indicatorWeight: 3,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Applied'),
            Tab(text: 'Exam Soon'),
            Tab(text: 'Results'),
          ],
        ),
      ),
      body: Consumer<JobsProvider>(
        builder: (context, jobsProvider, _) {
          if (jobsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE91E63),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildJobList(jobsProvider.savedJobs, 'all'),
              _buildJobList(
                jobsProvider.savedJobs
                    .where((j) => j.status == JobStatus.applied)
                    .toList(),
                'applied',
              ),
              _buildJobList(
                jobsProvider.savedJobs
                    .where((j) => j.status == JobStatus.examSoon)
                    .toList(),
                'exam',
              ),
              _buildJobList(
                jobsProvider.savedJobs
                    .where((j) => j.status == JobStatus.resultOut)
                    .toList(),
                'results',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJobList(List<Job> jobs, String tabType) {
    if (jobs.isEmpty) {
      return _buildEmptyState(tabType);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Dismissible(
          key: Key(job.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
                SizedBox(height: 4),
                Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Remove Job?'),
                content: Text('Remove "${job.title}" from saved jobs?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            context.read<JobsProvider>().removeSavedJob(job.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${job.title} removed'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    context.read<JobsProvider>().toggleBookmark(job.id);
                  },
                ),
              ),
            );
          },
          child: _buildSavedJobCard(job),
        );
      },
    );
  }

  Widget _buildSavedJobCard(Job job) {
    return GestureDetector(
      onTap: () => context.push('/job/${job.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getStatusColor(job.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(job.status),
                    color: _getStatusColor(job.status),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(job.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusLabel(job.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(job.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Days left or date
                Text(
                  job.daysLeft > 0 ? '${job.daysLeft}d left' : 'Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        job.daysLeft <= 7 ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String tabType) {
    String message;
    IconData icon;

    switch (tabType) {
      case 'applied':
        message = 'No applied jobs yet.\nApply to jobs to track them here.';
        icon = Icons.send_rounded;
        break;
      case 'exam':
        message = 'No upcoming exams.\nApplied jobs with exam dates will appear here.';
        icon = Icons.event_rounded;
        break;
      case 'results':
        message = 'No results available.\nResults for your applied jobs will appear here.';
        icon = Icons.emoji_events_rounded;
        break;
      default:
        message = 'No saved jobs yet.\nBookmark jobs to save them for later.';
        icon = Icons.bookmark_outline_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(JobStatus? status) {
    switch (status) {
      case JobStatus.applied:
        return Colors.blue;
      case JobStatus.examSoon:
        return Colors.orange;
      case JobStatus.resultOut:
        return Colors.green;
      default:
        return const Color(0xFFE91E63);
    }
  }

  IconData _getStatusIcon(JobStatus? status) {
    switch (status) {
      case JobStatus.applied:
        return Icons.check_circle_rounded;
      case JobStatus.examSoon:
        return Icons.event_rounded;
      case JobStatus.resultOut:
        return Icons.emoji_events_rounded;
      default:
        return Icons.bookmark_rounded;
    }
  }

  String _getStatusLabel(JobStatus? status) {
    switch (status) {
      case JobStatus.applied:
        return 'Applied';
      case JobStatus.examSoon:
        return 'Exam Soon';
      case JobStatus.resultOut:
        return 'Result Out';
      default:
        return 'Saved';
    }
  }
}
