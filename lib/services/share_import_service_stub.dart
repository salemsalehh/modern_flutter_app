import 'share_import_service.dart';

ShareImportService createShareImportService() => _StubShareImportService();

class _StubShareImportService implements ShareImportService {
  @override
  Stream<String> get textStream => const Stream.empty();

  @override
  Future<String?> get initialText async => null;

  @override
  Future<void> reset() async {}
}
