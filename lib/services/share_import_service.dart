import 'share_import_service_stub.dart'
    if (dart.library.io) 'share_import_service_mobile.dart';

abstract class ShareImportService {
  Stream<String> get textStream;
  Future<String?> get initialText;
  Future<void> reset();

  factory ShareImportService() => createShareImportService();
}
