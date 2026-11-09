import 'dart:typed_data';

import '../../settings/models/account_settings.dart';
import '../models/profile_entries.dart';
import '../services/profile_service.dart';

class ProfileRepository {
  final ProfileService _profileService = ProfileService();

  /// The whole saved profile of the signed-in account, in one read.
  Future<ProfileSnapshot> fetchProfile() => _profileService.fetchProfile();

  Future<({String name, String avatarUrl})> save({
    required String name,
    String title = '',
    String bio = '',
    double? hourlyRate,
    List<String> skills = const [],
    ProfileContext? context,
    String? githubUrl,
    String? websiteUrl,
    String? youtubeUrl,
  }) => _profileService.save(
    name: name,
    title: title,
    bio: bio,
    hourlyRate: hourlyRate,
    skills: skills,
    context: context,
    githubUrl: githubUrl,
    websiteUrl: websiteUrl,
    youtubeUrl: youtubeUrl,
  );

  Future<String> uploadAvatar(
    Uint8List bytes, {
    String filename = 'avatar.jpg',
    String mimeType = 'image/jpeg',
  }) => _profileService.uploadAvatar(
    bytes,
    filename: filename,
    mimeType: mimeType,
  );

  Future<void> removeAvatar() => _profileService.removeAvatar();

  Future<Language> saveLanguage(Language row) =>
      _profileService.saveLanguage(row);

  Future<void> removeLanguage(Language row) =>
      _profileService.removeLanguage(row);

  Future<Education> saveEducation(Education row) =>
      _profileService.saveEducation(row);

  Future<void> removeEducation(Education row) =>
      _profileService.removeEducation(row);

  Future<Certification> saveCertification(Certification row) =>
      _profileService.saveCertification(row);

  Future<void> removeCertification(Certification row) =>
      _profileService.removeCertification(row);

  Future<Employment> saveEmployment(Employment row) =>
      _profileService.saveEmployment(row);

  Future<void> removeEmployment(Employment row) =>
      _profileService.removeEmployment(row);

  Future<PortfolioItem> addPortfolio(PortfolioDraft draft) =>
      _profileService.addPortfolio(draft);

  Future<void> removePortfolio(PortfolioItem item) =>
      _profileService.removePortfolio(item);

  Future<String> saveVideoIntro(String url) =>
      _profileService.saveVideoIntro(url);

  Future<void> removeVideoIntro() => _profileService.removeVideoIntro();
}
