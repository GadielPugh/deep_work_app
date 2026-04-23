import 'package:deep_work/services/storage/local_coach_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service_factory.dart';

/// Central place for app-wide services.
///
/// Swap [sessionStorage] for [FakeSessionStorageService] in tests.
final class AppServices {
  AppServices._();

  static SessionStorageService sessionStorage = createSessionStorageService();
  static LocalCoachStorageService coachStorage = LocalCoachStorageService();
}
