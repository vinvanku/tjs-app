/// Represents a user profile in the Telangana Jobs App.
class Profile {
  final String id;
  final String phone;
  final String name;
  final String district;
  final String qualification;
  final List<String> preferredCategories;
  final String? fcmToken;
  final String language; // 'en' or 'te'

  const Profile({
    required this.id,
    required this.phone,
    required this.name,
    required this.district,
    required this.qualification,
    required this.preferredCategories,
    this.fcmToken,
    this.language = 'en',
  });

  /// Whether the profile is complete (has all required fields).
  bool get isComplete {
    return name.isNotEmpty &&
        district.isNotEmpty &&
        qualification.isNotEmpty &&
        preferredCategories.isNotEmpty;
  }

  /// Display name with fallback.
  String get displayName => name.isNotEmpty ? name : 'User';

  /// Creates a [Profile] from a JSON map (typically from Supabase response).
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      district: json['district'] as String? ?? '',
      qualification: json['qualification'] as String? ?? '',
      preferredCategories: json['preferred_categories'] != null
          ? List<String>.from(json['preferred_categories'] as List)
          : <String>[],
      fcmToken: json['fcm_token'] as String?,
      language: json['language'] as String? ?? 'en',
    );
  }

  /// Converts the [Profile] to a JSON map for Supabase insert/update.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'district': district,
      'qualification': qualification,
      'preferred_categories': preferredCategories,
      'fcm_token': fcmToken,
      'language': language,
    };
  }

  /// Creates a copy with the given fields replaced.
  Profile copyWith({
    String? id,
    String? phone,
    String? name,
    String? district,
    String? qualification,
    List<String>? preferredCategories,
    String? fcmToken,
    String? language,
  }) {
    return Profile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      district: district ?? this.district,
      qualification: qualification ?? this.qualification,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      fcmToken: fcmToken ?? this.fcmToken,
      language: language ?? this.language,
    );
  }

  /// Returns an empty profile for a given user ID and phone.
  factory Profile.empty(String userId, String phone) {
    return Profile(
      id: userId,
      phone: phone,
      name: '',
      district: '',
      qualification: '',
      preferredCategories: [],
      fcmToken: null,
      language: 'en',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Profile(id: $id, name: $name, district: $district)';
}
