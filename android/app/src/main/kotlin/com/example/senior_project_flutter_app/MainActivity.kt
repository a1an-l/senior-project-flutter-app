package com.example.senior_project_flutter_app

import android.content.pm.PackageManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "hiway/keys"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // This listens for the Flutter MethodChannel request
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      if (call.method == "mapsApiKey") {
        val apiKey = getApiKeyFromManifest()
        if (apiKey != null) {
          result.success(apiKey) // Send the key back to Flutter!
        } else {
          result.error("UNAVAILABLE", "API key not found in Manifest.", null)
        }
      } else {
        result.notImplemented()
      }
    }
  }

  // This grabs the securely injected API key from your AndroidManifest.xml
  private fun getApiKeyFromManifest(): String? {
    return try {
      val applicationInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
      val bundle = applicationInfo.metaData
      bundle.getString("com.google.android.geo.API_KEY")
    } catch (e: PackageManager.NameNotFoundException) {
      null
    } catch (e: NullPointerException) {
      null
    }
  }
}