import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/job.dart';
import '../models/profile.dart';

/// Service class that handles all Supabase database operations
/// for the Telangana Jobs application.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // JOBS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches jobs from the `jobs` table with optional filters.
  ///
  /// All filters are optional and can be combined:
  /// - [category]: Filter by job category (e.g., "Police", "Teaching")
  /// - [qualification]: Filter by required qualification
  /// - [district]: Filter by district name
  /// - [searchQuery]: Full-text search across title, organization, description
  Future<List<Job>> fetchJobs({
    String? category,
    String? qualification,
    String? district,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('jobs').select();

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (qualification != null && qualification.isNotEmpty) {
        query = query.eq('qualification', qualification);
      }

      if (district != null && district.isNotEmpty) {
        query = query.eq('district', district);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'title.ilike.%$searchQuery%,'
          'organization.ilike.%$searchQuery%,'
          'description.ilike.%$searchQuery%',
        );
      }

      final response = await query
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Job.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to fetch jobs: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to fetch jobs: $e');
    }
  }

  /// Fetches a single job by its unique [id].
  Future<Job> getJobById(String id) async {
    try {
      final response =
          await _client.from('jobs').select().eq('id', id).single();

      return Job.fromJson(response);
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to fetch job with id $id: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to fetch job with id $id: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVED JOBS
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a job for the user. Creates an entry in the `saved_jobs` table.
  Future<void> saveJob(String userId, String jobId) async {
    try {
      await _client.from('saved_jobs').upsert(
        {
          'user_id': userId,
          'job_id': jobId,
          'status': 'saved',
          'saved_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,job_id',
      );
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to save job: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to save job: $e');
    }
  }

  /// Removes a saved job for the user.
  Future<void> unsaveJob(String userId, String jobId) async {
    try {
      await _client
          .from('saved_jobs')
          .delete()
          .eq('user_id', userId)
          .eq('job_id', jobId);
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to unsave job: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to unsave job: $e');
    }
  }

  /// Retrieves all saved jobs for the user, joined with full job details.
  Future<List<Job>> getSavedJobs(String userId) async {
    try {
      final response = await _client
          .from('saved_jobs')
          .select('*, jobs(*)')
          .eq('user_id', userId)
          .order('saved_at', ascending: false);

      return (response as List<dynamic>).map((row) {
        final jobData = row['jobs'] as Map<String, dynamic>;
        // Merge saved_job metadata into the job data
        jobData['saved_job_id'] = row['id'];
        jobData['saved_status'] = row['status'];
        jobData['saved_at'] = row['saved_at'];
        return Job.fromJson(jobData);
      }).toList();
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to fetch saved jobs: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to fetch saved jobs: $e');
    }
  }

  /// Updates the status of a saved job entry (e.g., "saved", "applied", "expired").
  Future<void> updateSavedJobStatus(String id, String status) async {
    try {
      await _client.from('saved_jobs').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to update saved job status: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException(
          'Failed to update saved job status: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM TOKEN
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates the FCM push notification token for the given user.
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _client.from('user_devices').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': _getPlatform(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to update FCM token: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to update FCM token: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  /// Retrieves the user profile for the given [userId].
  /// Returns `null` if no profile exists.
  Future<Profile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to fetch user profile: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to fetch user profile: $e');
    }
  }

  /// Creates or updates the user profile.
  Future<void> updateProfile(Profile profile) async {
    try {
      await _client.from('profiles').upsert(
        profile.toJson(),
        onConflict: 'user_id',
      );
    } on PostgrestException catch (e) {
      throw SupabaseServiceException(
        'Failed to update profile: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to update profile: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _getPlatform() {
    // Use defaultTargetPlatform or similar detection in production
    return 'android'; // Default; override via dart:io or foundation
  }
}

/// Custom exception class for SupabaseService errors.
class SupabaseServiceException implements Exception {
  final String message;
  final String? code;

  SupabaseServiceException(this.message, {this.code});

  @override
  String toString() => 'SupabaseServiceException: $message (code: $code)';
}
