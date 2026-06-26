import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isTeluguSelected = true;

  final List<OnboardingPage> _pagesEnglish = [
    OnboardingPage(
      icon: Icons.notifications_active_rounded,
      title: 'Get Telangana Govt Job\nAlerts Instantly',
      description:
          'Stay updated with the latest government job notifications from TSPSC, TSLPRB, and all Telangana recruitment boards.',
      color: const Color(0xFFE91E63),
    ),
    OnboardingPage(
      icon: Icons.download_rounded,
      title: 'Download Notification\nPDFs Offline',
      description:
          'Save official job notification PDFs to your device and access them anytime without internet connection.',
      color: const Color(0xFF9C27B0),
    ),
    OnboardingPage(
      icon: Icons.tune_rounded,
      title: 'Set Your Qualification &\nGet Matched Jobs',
      description:
          'Tell us your education, preferred district, and job category. We\'ll show you only the jobs you\'re eligible for.',
      color: const Color(0xFF3F51B5),
    ),
  ];

  final List<OnboardingPage> _pagesTelugu = [
    OnboardingPage(
      icon: Icons.notifications_active_rounded,
      title: 'తెలంగాణ ప్రభుత్వ ఉద్యోగ\nఅలర్ట్‌లు తక్షణమే పొందండి',
      description:
          'TSPSC, TSLPRB మరియు అన్ని తెలంగాణ రిక్రూట్‌మెంట్ బోర్డుల నుండి తాజా ప్రభుత్వ ఉద్యోగ నోటిఫికేషన్‌లతో అప్‌డేట్ అవ్వండి.',
      color: const Color(0xFFE91E63),
    ),
    OnboardingPage(
      icon: Icons.download_rounded,
      title: 'నోటిఫికేషన్ PDFలను\nఆఫ్‌లైన్‌లో డౌన్‌లోడ్ చేయండి',
      description:
          'అధికారిక ఉద్యోగ నోటిఫికేషన్ PDFలను మీ పరికరంలో సేవ్ చేసి, ఇంటర్నెట్ కనెక్షన్ లేకుండా ఎప్పుడైనా యాక్సెస్ చేయండి.',
      color: const Color(0xFF9C27B0),
    ),
    OnboardingPage(
      icon: Icons.tune_rounded,
      title: 'మీ అర్హతను సెట్ చేసి\nసరిపోలిన ఉద్యోగాలు పొందండి',
      description:
          'మీ విద్య, ప్రాధాన్య జిల్లా మరియు ఉద్యోగ వర్గాన్ని మాకు చెప్పండి. మీకు అర్హత ఉన్న ఉద్యోగాలను మాత్రమే మేము చూపిస్తాము.',
      color: const Color(0xFF3F51B5),
    ),
  ];

  List<OnboardingPage> get _pages =>
      _isTeluguSelected ? _pagesTelugu : _pagesEnglish;

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    final authProvider = context.read<AuthProvider>();
    authProvider.setOnboardingSeen();
    context.go('/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Language Toggle at top
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        _buildLanguageChip(
                          label: 'తెలుగు',
                          isSelected: _isTeluguSelected,
                          onTap: () => setState(() => _isTeluguSelected = true),
                        ),
                        _buildLanguageChip(
                          label: 'English',
                          isSelected: !_isTeluguSelected,
                          onTap: () =>
                              setState(() => _isTeluguSelected = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon container
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: page.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 70,
                            color: page.color,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade900,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom section with dots and buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFFE91E63)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip button
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          _isTeluguSelected ? 'దాటవేయి' : 'Skip',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Next / Get Started button
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                          shadowColor:
                              const Color(0xFFE91E63).withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? (_isTeluguSelected
                                      ? 'ప్రారంభించండి'
                                      : 'Get Started')
                                  : (_isTeluguSelected ? 'తదుపరి' : 'Next'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE91E63) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
