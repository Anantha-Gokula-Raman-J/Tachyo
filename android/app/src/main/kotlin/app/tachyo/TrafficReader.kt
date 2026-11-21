package app.tachyo

import android.net.TrafficStats
import android.os.SystemClock

/** Cumulative byte counters since boot. Wi-Fi is everything that is not mobile. */
data class Counters(
    val rx: Long,
    val tx: Long,
    val mobileRx: Long,
    val mobileTx: Long,
    val timeMs: Long,
) {
    val wifiRx get() = (rx - mobileRx).coerceAtLeast(0)
    val wifiTx get() = (tx - mobileTx).coerceAtLeast(0)

    fun toMap(): Map<String, Any> = mapOf(
        "rx" to rx, "tx" to tx,
        "wifiRx" to wifiRx, "wifiTx" to wifiTx,
        "mobileRx" to mobileRx, "mobileTx" to mobileTx,
        "t" to timeMs,
    )
}

object TrafficReader {
    /** TrafficStats returns UNSUPPORTED (-1) on some devices and emulators: treat as 0. */
    private fun safe(v: Long) = if (v < 0) 0L else v

    fun read(): Counters = Counters(
        rx = safe(TrafficStats.getTotalRxBytes()),
        tx = safe(TrafficStats.getTotalTxBytes()),
        mobileRx = safe(TrafficStats.getMobileRxBytes()),
        mobileTx = safe(TrafficStats.getMobileTxBytes()),
        // Monotonic clock: wall-clock changes must not create fake speed spikes.
        timeMs = SystemClock.elapsedRealtime(),
    )
}
