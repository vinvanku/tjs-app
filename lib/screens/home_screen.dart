import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/auth_provider.dart';
import '../providers/jobs_provider.dart';
import '../providers/language_provider.dart';
import '../models/job_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  int _currentNavIndex = 0;
  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();
  bool _hasFetched = false;

  static const List<String> _categories = [
    'All',
    'Police',
    'Teaching',
    'Health',
    'Engineering',
    'Revenue',
    'Banking',
    'Railway',
    'Defense',
    'Research',
    'Agriculture',
    'Forest',
    'Judicial',
    'Postal',
    'Insurance',
    'Staff Selection',
    'Education',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final jobsProvider = context.read<JobsProvider>();
      // Only fetch if we haven't already or the list is empty
      if (_hasFetched && jobsProvider.jobs.isNotEmpty) return;
      _hasFetched = true;
      context.read<JobsProvider>().fetchJobs();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _onRefresh() async {
    await context.read<JobsProvider>().fetchJobs(refresh: true);
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    if (category == 'All') {
      context.read<JobsProvider>().filterByCategory(null);
    } else {
      // Map display names to exact DB values (all lowercase, underscores)
      const displayToDb = {
        'Police': 'police',
        'Teaching': 'teaching',
        'Health': 'health',
        'Engineering': 'engineering',
        'Revenue': 'revenue',
        'Banking': 'banking',
        'Railway': 'railway',
        'Defense': 'defense',
        'Research': 'research',
        'Agriculture': 'agriculture',
        'Forest': 'forest',
        'Judicial': 'judicial',
        'Postal': 'postal',
        'Insurance': 'insurance',
        'Staff Selection': 'staff_selection',
        'Education': 'education',
        'General': 'general',
      };
      context.read<JobsProvider>().filterByCategory(
        displayToDb[category] ?? category.toLowerCase(),
      );
    }
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break; // Already on home
      case 1:
        context.push('/search');
        break;
      case 2:
        context.push('/saved');
        break;
      case 3:
        context.push('/calendar');
        break;
      case 4:
        context.push('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFE91E63),
        child: Consumer<JobsProvider>(
          builder: (context, jobsProvider, _) {
            if (jobsProvider.isLoading && jobsProvider.jobs.isEmpty) {
              return _buildShimmerLoading();
            }

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Category Chips
                SliverToBoxAdapter(
                  child: _buildCategoryChips(),
                ),

                // Featured Jobs Carousel
                if (jobsProvider.featuredJobs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedCarousel(jobsProvider.featuredJobs),
                  ),

                // Section Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.watch<LanguageProvider>().getString('latest_jobs'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          '${jobsProvider.jobs.length} jobs',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Job List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= jobsProvider.jobs.length) return null;
                        return _buildJobCard(jobsProvider.jobs[index]);
                      },
                      childCount: jobsProvider.jobs.length,
                    ),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'TS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'TS Jobs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
      actions: [
        // Notification Bell
        Stack(
          children: [
            IconButton(
              onPressed: () => context.push('/notifications'),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF1A1A2E),
                size: 26,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        // Profile Avatar
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE91E63).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFE91E63).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    authProvider.userName.isNotEmpty
                        ? authProvider.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final lang = context.watch<LanguageProvider>();
    // Map internal category names to translation keys
    String categoryLabel(String category) {
      const keyMap = {
        'All': 'cat_all',
        'Police': 'cat_police',
        'Teaching': 'cat_teaching',
        'Health': 'cat_health',
        'Engineering': 'cat_engineering',
        'Revenue': 'cat_revenue',
        'Banking': 'cat_banking',
        'Railway': 'cat_railway',
        'Defense': 'cat_defense',
        'Research': 'cat_research',
        'Agriculture': 'cat_agriculture',
        'Forest': 'cat_forest',
        'Judicial': 'cat_judicial',
        'Postal': 'cat_postal',
        'Insurance': 'cat_insurance',
        'Staff Selection': 'cat_staff_selection',
        'Education': 'cat_education',
        'General': 'cat_general',
      };
      return lang.getString(keyMap[category] ?? category);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onCategorySelected(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE91E63)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE91E63)
                          : Colors.grey.shade300,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFFE91E63).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    categoryLabel(category),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFeaturedCarousel(List<Job> featuredJobs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            '🔥 Featured Jobs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: featuredJobs.length,
            itemBuilder: (context, index) {
              final job = featuredJobs[index];
              return GestureDetector(
                onTap: () => context.push('/job/${job.id}'),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              job.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            job.organization,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${job.vacancies} vacancies',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${job.daysLeft}d left',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE91E63),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobCard(Job job) {
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
                // Organization icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFFE91E63),
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
                // Bookmark
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
                        : Colors.grey.shade400,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Tags row
            Row(
              children: [
                _buildTag(job.category, Icons.category_outlined),
                const SizedBox(width: 8),
                _buildTag('${job.vacancies} posts', Icons.people_outline),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: job.daysLeft <= 7
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    job.daysLeft <= 0
                        ? 'Closed'
                        : '${job.daysLeft}d left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: job.daysLeft <= 7
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    final lang = context.watch<LanguageProvider>();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, lang.getString('nav_home')),
              _buildNavItem(1, Icons.search_rounded, lang.getString('nav_search')),
              _buildNavItem(2, Icons.bookmark_rounded, lang.getString('nav_saved')),
              _buildNavItem(3, Icons.calendar_month_rounded, lang.getString('nav_calendar')),
              _buildNavItem(4, Icons.person_rounded, lang.getString('nav_profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavIndex = index);
        _onNavTap(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color:
                isSelected ? const Color(0xFFE91E63) : Colors.grey.shade500,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color:
                  isSelected ? const Color(0xFFE91E63) : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
