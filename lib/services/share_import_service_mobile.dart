import 'package:flutter/services.dart';

import 'share_import_service.dart';

ShareImportService createShareImportService() => _MobileShareImportService();

class _MobileShareImportService implements ShareImportService {
  static const MethodChannel _method = MethodChannel('share_intent/text');
  static const EventChannel _events = EventChannel('share_intent/text_events');

  Stream<String>? _cached;

  @override
  Stream<String> get textStream =>
      _cached ??= _events.receiveBroadcastStream().where((e) => e is String).cast<String>();

  @override
  Future<String?> get initialText async {
    final res = await _method.invokeMethod<dynamic>('getInitialText');
    return res?.toString();
  }

  @override
  Future<void> reset() async {
    await _method.invokeMethod<void>('reset');
  }
}
