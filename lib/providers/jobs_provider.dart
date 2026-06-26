import 'package:flutter/foundation.dart';

import '../models/job.dart';
import '../services/supabase_service.dart';

/// Provider class that manages jobs state including fetching, filtering,
/// searching, and saved jobs management.
///
/// Uses [ChangeNotifier] for state management with Flutter's Provider package.
class JobsProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────────────────

  List<Job> _jobs = [];
  List<Job> _filteredJobs = [];
  List<Job> _savedJobs = [];
  Job? _selectedJob;

  String? _selectedCategory;
  String? _selectedQualification;
  String? _selectedDistrict;
  String _searchQuery = '';

  bool _isLoading = false;
  bool _isSavedJobsLoading = false;
  String? _errorMessage;
  String? _userId;

  // Set of saved job IDs for quick lookup
  final Set<String> _savedJobIds = {};

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// All fetched jobs (unfiltered).
  List<Job> get jobs => _jobs;

  /// Jobs after applying filters and search.
  List<Job> get filteredJobs => _filteredJobs;

  /// User's saved/bookmarked jobs.
  List<Job> get savedJobs => _savedJobs;

  /// Currently selected job for detail view.
  Job? get selectedJob => _selectedJob;

  /// Currently selected category filter.
  String? get selectedCategory => _selectedCategory;

  /// Currently selected qualification filter.
  String? get selectedQualification => _selectedQualification;

  /// Currently selected district filter.
  String? get selectedDistrict => _selectedDistrict;

  /// Current search query.
  String get searchQuery => _searchQuery;

  /// Whether jobs are being loaded.
  bool get isLoading => _isLoading;

  /// Whether saved jobs are being loaded.
  bool get isSavedJobsLoading => _isSavedJobsLoading;

  /// Error message from the last failed operation.
  String? get errorMessage => _errorMessage;

  /// Whether a job is saved by the user.
  bool isJobSaved(String jobId) => _savedJobIds.contains(jobId);

  /// Total number of jobs.
  int get totalJobs => _jobs.length;

  /// Total number of filtered results.
  int get filteredCount => _filteredJobs.length;

  /// Total number of saved jobs.
  int get savedCount => _savedJobs.length;

  /// Whether any filters are currently active.
  bool get hasActiveFilters =>
      _selectedCategory != null ||
      _selectedQualification != null ||
      _selectedDistrict != null ||
      _searchQuery.isNotEmpty;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Sets the user ID and loads initial data.
  Future<void> initialize(String userId) async {
    _userId = userId;
    await Future.wait([
      fetchJobs(),
      loadSavedJobs(),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH JOBS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches jobs from the database with current filters applied.
  ///
  /// Sets [isLoading] to `true` during the operation.
  Future<void> fetchJobs() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _jobs = await _supabaseService.fetchJobs(
        category: _selectedCategory,
        qualification: _selectedQualification,
        district: _selectedDistrict,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      _filteredJobs = List.from(_jobs);
    } on SupabaseServiceException catch (e) {
      _errorMessage = e.message;
      _jobs = [];
      _filteredJobs = [];
    } catch (e) {
      _errorMessage = 'Failed to load jobs. Please try again.';
      _jobs = [];
      _filteredJobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches a single job by [id] and sets it as the selected job.
  Future<void> fetchJobById(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _selectedJob = await _supabaseService.getJobById(id);
    } on SupabaseServiceException catch (e) {
      _errorMessage = e.message;
      _selectedJob = null;
    } catch (e) {
      _errorMessage = 'Failed to load job details.';
      _selectedJob = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTERING
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters jobs by [category]. Pass `null` to clear the category filter.
  ///
  /// Triggers a fresh fetch from the database with the new filter.
  Future<void> filterByCategory(String? category) async {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    await fetchJobs();
  }

  /// Filters jobs by [qualification]. Pass `null` to clear.
  Future<void> filterByQualification(String? qualification) async {
    if (_selectedQualification == qualification) return;
    _selectedQualification = qualification;
    await fetchJobs();
  }

  /// Filters jobs by [district]. Pass `null` to clear.
  Future<void> filterByDistrict(String? district) async {
    if (_selectedDistrict == district) return;
    _selectedDistrict = district;
    await fetchJobs();
  }

  /// Searches jobs by [query] text. Pass empty string to clear search.
  ///
  /// Performs server-side search across title, organization, and description.
  Future<void> searchJobs(String query) async {
    final trimmed = query.trim();
    if (_searchQuery == trimmed) return;
    _searchQuery = trimmed;
    await fetchJobs();
  }

  /// Applies local filtering on already-fetched jobs (for instant UI feedback).
  ///
  /// Use this for quick client-side filtering without a network call.
  void filterLocally(String query) {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredJobs = List.from(_jobs);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      _filteredJobs = _jobs.where((job) {
        return job.title.toLowerCase().contains(lowerQuery) ||
            job.organization.toLowerCase().contains(lowerQuery) ||
            (job.description?.toLowerCase().contains(lowerQuery) ?? false) ||
            (job.category?.toLowerCase().contains(lowerQuery) ?? false) ||
            (job.district?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    notifyListeners();
  }

  /// Clears all active filters and refreshes the job list.
  Future<void> clearFilters() async {
    _selectedCategory = null;
    _selectedQualification = null;
    _selectedDistrict = null;
    _searchQuery = '';
    await fetchJobs();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVED JOBS
  // ─────────────────────────────────────────────────────────────────────────

  /// Loads all saved jobs for the current user.
  Future<void> loadSavedJobs() async {
    if (_userId == null) return;

    try {
      _isSavedJobsLoading = true;
      notifyListeners();

      _savedJobs = await _supabaseService.getSavedJobs(_userId!);
      _savedJobIds.clear();
      for (final job in _savedJobs) {
        _savedJobIds.add(job.id);
      }
    } on SupabaseServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      // Silent failure for saved jobs loading
    } finally {
      _isSavedJobsLoading = false;
      notifyListeners();
    }
  }

  /// Toggles the save state of a job.
  ///
  /// If the job is currently saved, it will be unsaved, and vice versa.
  /// Optimistically updates the UI before the server call completes.
  Future<void> toggleSaveJob(Job job) async {
    if (_userId == null) return;

    final isSaved = _savedJobIds.contains(job.id);

    // Optimistic update
    if (isSaved) {
      _savedJobIds.remove(job.id);
      _savedJobs.removeWhere((j) => j.id == job.id);
    } else {
      _savedJobIds.add(job.id);
      _savedJobs.insert(0, job);
    }
    notifyListeners();

    try {
      if (isSaved) {
        await _supabaseService.unsaveJob(_userId!, job.id);
      } else {
        await _supabaseService.saveJob(_userId!, job.id);
      }
    } catch (e) {
      // Revert optimistic update on failure
      if (isSaved) {
        _savedJobIds.add(job.id);
        _savedJobs.insert(0, job);
      } else {
        _savedJobIds.remove(job.id);
        _savedJobs.removeWhere((j) => j.id == job.id);
      }
      _errorMessage = 'Failed to ${isSaved ? 'unsave' : 'save'} job.';
      notifyListeners();
    }
  }

  /// Updates the status of a saved job (e.g., "applied", "expired").
  Future<void> updateSavedJobStatus(String savedJobId, String status) async {
    try {
      await _supabaseService.updateSavedJobStatus(savedJobId, status);
      await loadSavedJobs(); // Refresh the list
    } on SupabaseServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELECTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Sets the selected job for the detail view.
  void selectJob(Job job) {
    _selectedJob = job;
    notifyListeners();
  }

  /// Clears the selected job.
  void clearSelectedJob() {
    _selectedJob = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REFRESH & CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Refreshes all data (jobs and saved jobs).
  Future<void> refresh() async {
    await Future.wait([
      fetchJobs(),
      loadSavedJobs(),
    ]);
  }

  /// Clears error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Resets all state (e.g., on logout).
  void reset() {
    _jobs = [];
    _filteredJobs = [];
    _savedJobs = [];
    _selectedJob = null;
    _selectedCategory = null;
    _selectedQualification = null;
    _selectedDistrict = null;
    _searchQuery = '';
    _isLoading = false;
    _isSavedJobsLoading = false;
    _errorMessage = null;
    _userId = null;
    _savedJobIds.clear();
    notifyListeners();
  }
}
