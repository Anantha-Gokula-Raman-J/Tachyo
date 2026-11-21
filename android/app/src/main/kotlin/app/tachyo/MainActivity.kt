package app.tachyo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and the platform channel. Method names are the shared
 * contract with lib/src/platform/native_bridge.dart (specs/platform/channel.md).
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "app.tachyo/native"
        private const val REQ_NOTIFICATIONS = 7301
    }

    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getCounters" -> result.success(TrafficReader.read().toMap())
                "startMeter" -> {
                    Prefs.setMeterEnabled(this, true)
                    MeterService.start(this)
                    result.success(true)
                }
                "stopMeter" -> {
                    Prefs.setMeterEnabled(this, false)
                    MeterService.stop(this)
                    result.success(null)
                }
                "isMeterRunning" -> result.success(MeterService.running)
                "requestNotificationPermission" -> requestNotifications(result)
                "getDailyUsage" -> {
                    val days = call.argument<Int>("days") ?: 30
                    result.success(UsageStore.recent(this, days).map { it.toMap() })
                }
                "addUsage" -> {
                    val date = call.argument<String>("date") ?: UsageStore.dayKey()
                    fun n(k: String) = (call.argument<Number>(k) ?: 0).toLong()
                    UsageStore.add(
                        this, date,
                        UsageRecord(
                            date,
                            // Android has no separate "other" bucket: fold it into Wi-Fi.
                            wifiRx = n("wifiRx") + n("otherRx"),
                            wifiTx = n("wifiTx") + n("otherTx"),
                            mobileRx = n("mobileRx"),
                            mobileTx = n("mobileTx"),
                        ),
                    )
                    result.success(null)
                }
                "getSettings" -> result.success(Prefs.toMap(this))
                "getDataDir" -> result.success(filesDir.absolutePath)
                "saveSettings" -> {
                    @Suppress("UNCHECKED_CAST")
                    Prefs.save(this, call.arguments as? Map<String, Any?> ?: emptyMap())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("native_error", e.message, null)
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermission?.success(granted)
            pendingPermission = null
        }
    }
}
