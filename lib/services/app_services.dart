import 'package:deep_work/services/storage/local_session_storage_service.dart';
import 'package:deep_work/services/storage/local_coach_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';

/// Central place for app-wide services.
///
/// Swap [sessionStorage] for [FakeSessionStorageService] in tests.
final class AppServices {
  AppServices._();

  static SessionStorageService sessionStorage = LocalSessionStorageService();
  static LocalCoachStorageService coachStorage = LocalCoachStorageService();
}
