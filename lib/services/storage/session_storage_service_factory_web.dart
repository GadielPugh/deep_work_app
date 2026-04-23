import 'package:deep_work/services/storage/local_session_storage_web_service.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';

SessionStorageService createSessionStorageService() {
  return LocalSessionStorageWebService();
}
