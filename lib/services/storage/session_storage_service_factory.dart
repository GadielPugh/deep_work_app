import 'package:deep_work/services/storage/session_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service_factory_native.dart'
    if (dart.library.html) 'package:deep_work/services/storage/session_storage_service_factory_web.dart'
    as storage_factory;

SessionStorageService createSessionStorageService() {
  return storage_factory.createSessionStorageService();
}
