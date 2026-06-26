import 'package:flutter/material.dart';
import 'category_chip.dart';

/// Filter criteria model for job search.
class JobFilter {
  final Set<String> selectedCategories;
  final String? qualification;
  final String? district;
  final bool freeOnly;
  final int? daysLeftMax; // null = Any, 7, 30

  const JobFilter({
    this.selectedCategories = const {},
    this.qualification,
    this.district,
    this.freeOnly = false,
    this.daysLeftMax,
  });

  JobFilter copyWith({
    Set<String>? selectedCategories,
    String? qualification,
    String? district,
    bool? freeOnly,
    int? daysLeftMax,
    bool clearQualification = false,
    bool clearDistrict = false,
    bool clearDaysLeft = false,
  }) {
    return JobFilter(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      qualification: clearQualification ? null : (qualification ?? this.qualification),
      district: clearDistrict ? null : (district ?? this.district),
      freeOnly: freeOnly ?? this.freeOnly,
      daysLeftMax: clearDaysLeft ? null : (daysLeftMax ?? this.daysLeftMax),
    );
  }

  static const JobFilter empty = JobFilter();
}

/// A bottom sheet modal for filtering job listings.
///
/// Includes:
/// - Category multi-select chips
/// - Qualification dropdown
/// - District dropdown
/// - "Free applications only" toggle
/// - Days left slider (Any / <7 / <30)
/// - Apply and Reset buttons
class FilterSheet extends StatefulWidget {
  final JobFilter initialFilter;
  final ValueChanged<JobFilter> onApply;

  const FilterSheet({
    super.key,
    this.initialFilter = JobFilter.empty,
    required this.onApply,
  });

  /// Show the filter sheet as a modal bottom sheet.
  static Future<JobFilter?> show(
    BuildContext context, {
    JobFilter initialFilter = JobFilter.empty,
    required ValueChanged<JobFilter> onApply,
  }) {
    return showModalBottomSheet<JobFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        initialFilter: initialFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Set<String> _selectedCategories;
  late String? _qualification;
  late String? _district;
  late bool _freeOnly;
  late int? _daysLeftMax;

  // Available options
  static const List<String> _categories = [
    'Police',
    'Teaching',
    'Health',
    'Engineering',
    'Revenue',
    'General',
  ];

  static const List<String> _qualifications = [
    '10th Pass',
    'Inter / 12th',
    'Degree / Graduation',
    'Post Graduation',
    'B.Tech / B.E.',
    'MBBS / MD',
    'B.Ed',
    'ITI / Diploma',
    'Any',
  ];

  static const List<String> _districts = [
    'Hyderabad',
    'Rangareddy',
    'Medchal-Malkajgiri',
    'Sangareddy',
    'Warangal',
    'Karimnagar',
    'Khammam',
    'Nizamabad',
    'Mahabubnagar',
    'Nalgonda',
    'Adilabad',
    'Siddipet',
    'Suryapet',
    'Mancherial',
    'Jagtial',
    'Peddapalli',
    'Kamareddy',
    'Wanaparthy',
    'Jogulamba Gadwal',
    'Medak',
    'Nagarkurnool',
    'Bhadradri Kothagudem',
    'Jangaon',
    'Yadadri Bhuvanagiri',
    'Vikarabad',
    'Rajanna Sircilla',
    'Jayashankar Bhupalpally',
    'Mulugu',
    'Narayanpet',
    'Kumuram Bheem Asifabad',
    'All Districts',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.initialFilter.selectedCategories);
    _qualification = widget.initialFilter.qualification;
    _district = widget.initialFilter.district;
    _freeOnly = widget.initialFilter.freeOnly;
    _daysLeftMax = widget.initialFilter.daysLeftMax;
  }

  void _reset() {
    setState(() {
      _selectedCategories = {};
      _qualification = null;
      _district = null;
      _freeOnly = false;
      _daysLeftMax = null;
    });
  }

  void _apply() {
    final filter = JobFilter(
      selectedCategories: _selectedCategories,
      qualification: _qualification,
      district: _district,
      freeOnly: _freeOnly,
      daysLeftMax: _daysLeftMax,
    );
    widget.onApply(filter);
    Navigator.of(context).pop(filter);
  }

  double get _sliderValue {
    if (_daysLeftMax == null) return 0;
    if (_daysLeftMax == 7) return 1;
    if (_daysLeftMax == 30) return 2;
    return 0;
  }

  String get _sliderLabel {
    if (_daysLeftMax == null) return 'Any';
    if (_daysLeftMax == 7) return '< 7 days';
    if (_daysLeftMax == 30) return '< 30 days';
    return 'Any';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 22, color: Color(0xFF1A1A2E)),
                  const SizedBox(width: 10),
                  const Text(
                    'Filter Jobs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category multi-select
                    _sectionTitle('Category'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategories.contains(cat);
                        return CategoryChip(
                          label: cat,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCategories.remove(cat);
                              } else {
                                _selectedCategories.add(cat);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Qualification dropdown
                    _sectionTitle('Qualification'),
                    const SizedBox(height: 10),
                    _buildDropdown(
                      value: _qualification,
                      hint: 'Select qualification',
                      items: _qualifications,
                      onChanged: (val) => setState(() => _qualification = val),
                    ),

                    const SizedBox(height: 24),

                    // District dropdown
                    _sectionTitle('District'),
                    const SizedBox(height: 10),
                    _buildDropdown(
                      value: _district,
                      hint: 'Select district',
                      items: _districts,
                      onChanged: (val) => setState(() => _district = val),
                    ),

                    const SizedBox(height: 24),

                    // Free applications toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.money_off,
                              size: 20, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Free applications only',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _freeOnly,
                            activeColor: const Color(0xFFE91E63),
                            onChanged: (val) =>
                                setState(() => _freeOnly = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Days left slider
                    _sectionTitle('Days Left'),
                    const SizedBox(height: 4),
                    Text(
                      _sliderLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFE91E63),
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: const Color(0xFFE91E63),
                        overlayColor:
                            const Color(0xFFE91E63).withOpacity(0.12),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _sliderValue,
                        min: 0,
                        max: 2,
                        divisions: 2,
                        onChanged: (val) {
                          setState(() {
                            if (val == 0) {
                              _daysLeftMax = null;
                            } else if (val == 1) {
                              _daysLeftMax = 7;
                            } else {
                              _daysLeftMax = 30;
                            }
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Any',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        Text('< 7 days',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        Text('< 30 days',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Apply button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A2E),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF424242),
            fontWeight: FontWeight.w500,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
