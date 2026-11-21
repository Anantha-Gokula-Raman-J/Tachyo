package app.tachyo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Restarts the status-bar meter after reboot or app update when the user enabled it. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        if (!Prefs.meterEnabled(context)) return
        if (action == Intent.ACTION_BOOT_COMPLETED && !Prefs.bootStart(context)) return
        try {
            MeterService.start(context)
        } catch (e: Exception) {
            // Background start can be refused by the OS (e.g. battery restrictions);
            // the meter resumes the next time the app is opened.
            Log.w("Tachyo", "Could not start meter after $action", e)
        }
    }
}
