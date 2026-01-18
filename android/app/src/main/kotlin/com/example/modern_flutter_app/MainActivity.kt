package com.example.modern_flutter_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val methodChannelName = "share_intent/text"
  private val eventChannelName = "share_intent/text_events"

  private var eventSink: EventChannel.EventSink? = null
  private var pendingText: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getInitialText" -> result.success(pendingText)
          "reset" -> {
            pendingText = null
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
      .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
          eventSink = sink
          val t = pendingText
          if (t != null) {
            sink?.success(t)
            pendingText = null
          }
        }

        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      })

    handleShareIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleShareIntent(intent)
  }

  private fun handleShareIntent(intent: Intent?) {
    if (intent == null) return
    if (Intent.ACTION_SEND != intent.action) return
    if (intent.type != "text/plain") return

    val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return

    val sink = eventSink
    if (sink != null) {
      sink.success(text)
    } else {
      pendingText = text
    }
  }
}
