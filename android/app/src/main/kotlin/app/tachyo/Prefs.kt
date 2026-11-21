package app.tachyo

import android.content.Context

/** App settings shared by the UI (via the channel), the meter service and the boot receiver. */
object Prefs {
    private const val FILE = "tachyo_settings"

    private fun p(c: Context) = c.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun unitBits(c: Context) = p(c).getBoolean("unitBits", true)
    fun meterEnabled(c: Context) = p(c).getBoolean("meterEnabled", false)
    fun bootStart(c: Context) = p(c).getBoolean("bootStart", true)
    /** 0 = auto, 1..3 = fixed unit (see SpeedFormat.speed). */
    fun speedScale(c: Context) = p(c).getInt("speedScale", 0)
    fun setMeterEnabled(c: Context, v: Boolean) = p(c).edit().putBoolean("meterEnabled", v).apply()

    fun toMap(c: Context): Map<String, Any> = mapOf(
        "unitBits" to unitBits(c),
        "meterEnabled" to meterEnabled(c),
        "bootStart" to bootStart(c),
        "alwaysOnTop" to p(c).getBoolean("alwaysOnTop", true),
        "speedScale" to speedScale(c),
    )

    fun save(c: Context, values: Map<String, Any?>) {
        val e = p(c).edit()
        for ((k, v) in values) when (v) {
            is Boolean -> e.putBoolean(k, v)
            is Number -> e.putInt(k, v.toInt())
        }
        e.apply()
    }
}
