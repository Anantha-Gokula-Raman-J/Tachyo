package app.tachyo

import java.util.Locale
import kotlin.math.roundToLong

/**
 * Mirror of lib/src/core/format.dart (formatSpeed / compactSpeed / formatBytes).
 * Bytes use a 1024 base, bits a 1000 base. Keep both files in step.
 */
object SpeedFormat {
    private val byteUnits = listOf("B/s", "KB/s", "MB/s", "GB/s")
    private val bitUnits = listOf("bps", "Kbps", "Mbps", "Gbps")
    private val sizeUnits = listOf("B", "KB", "MB", "GB", "TB")

    /** [scale]: 0 = auto, 1..3 = fixed B/s, KB/s, MB/s (bps, Kbps, Mbps). */
    fun speed(bytesPerSecond: Double, bits: Boolean, scale: Int = 0): Pair<String, String> {
        val safe = if (bytesPerSecond.isFinite() && bytesPerSecond > 0) bytesPerSecond else 0.0
        val base = if (bits) 1000.0 else 1024.0
        val units = if (bits) bitUnits else byteUnits
        var v = if (bits) safe * 8 else safe
        var i = 0
        if (scale in 1..3) {
            i = scale - 1
            repeat(i) { v /= base }
            return (if (bits) bitDecimals(v, i == 0) else decimals(v, i == 0)) to units[i]
        }
        while (v >= base && i < units.size - 1) { v /= base; i++ }
        if ((v >= 1000 || (bits && v >= 999.95)) && i < units.size - 1) { v /= base; i++ }
        return (if (bits) bitDecimals(v, i == 0) else decimals(v, i == 0)) to units[i]
    }

    /** Bits: one decimal ("144.4 Mbps"); bps and 1000+ are whole numbers. */
    private fun bitDecimals(v: Double, integerOnly: Boolean): String =
        if (integerOnly || v >= 1000) v.roundToLong().toString() else String.format(Locale.US, "%.1f", v)

    /** Short value + unit for the status-bar icon, e.g. ("1.2", "MB"). */
    fun compact(bytesPerSecond: Double, bits: Boolean, scale: Int = 0): Pair<String, String> {
        var (value, unit) = speed(bytesPerSecond, bits, scale)
        if ((value.toDoubleOrNull() ?: 0.0) >= 1000) { val auto = speed(bytesPerSecond, bits); value = auto.first; unit = auto.second }
        val v = value.toDoubleOrNull() ?: 0.0
        val text = if (v >= 10) v.roundToLong().toString() else String.format(Locale.US, "%.1f", v)
        return (if (text == "0.0") "0" else text) to unit.replace("/s", "").replace("ps", "")
    }

    fun bytes(count: Long): String {
        var v = if (count < 0) 0.0 else count.toDouble()
        var i = 0
        while (v >= 1024 && i < sizeUnits.size - 1) { v /= 1024; i++ }
        return "${decimals(v, i == 0)} ${sizeUnits[i]}"
    }

    private fun decimals(v: Double, integerOnly: Boolean): String = when {
        integerOnly -> v.roundToLong().toString()
        v < 10 -> String.format(Locale.US, "%.2f", v)
        v < 100 -> String.format(Locale.US, "%.1f", v)
        else -> v.roundToLong().toString()
    }
}
