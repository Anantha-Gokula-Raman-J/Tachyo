package app.tachyo

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class UsageRecord(
    val date: String,
    val wifiRx: Long = 0,
    val wifiTx: Long = 0,
    val mobileRx: Long = 0,
    val mobileTx: Long = 0,
) {
    val isEmpty get() = wifiRx == 0L && wifiTx == 0L && mobileRx == 0L && mobileTx == 0L
    val wifi get() = wifiRx + wifiTx
    val mobile get() = mobileRx + mobileTx

    operator fun plus(o: UsageRecord) =
        UsageRecord(date, wifiRx + o.wifiRx, wifiTx + o.wifiTx, mobileRx + o.mobileRx, mobileTx + o.mobileTx)

    fun encode() = "$wifiRx,$wifiTx,$mobileRx,$mobileTx"

    fun toMap(): Map<String, Any> = mapOf(
        "date" to date, "wifiRx" to wifiRx, "wifiTx" to wifiTx,
        "mobileRx" to mobileRx, "mobileTx" to mobileTx, "otherRx" to 0L, "otherTx" to 0L,
    )

    companion object {
        fun decode(date: String, raw: String?): UsageRecord {
            val p = raw?.split(',')?.map { it.toLongOrNull() ?: 0L } ?: return UsageRecord(date)
            if (p.size < 4) return UsageRecord(date)
            return UsageRecord(date, p[0], p[1], p[2], p[3])
        }
    }
}

/**
 * Per-day usage in SharedPreferences (tachyo_usage: yyyy-MM-dd -> "wRx,wTx,mRx,mTx").
 * One writer at a time: the meter service while it runs, otherwise the app
 * (MeterController.recordsUsageInApp). Synchronized because both share a process.
 */
object UsageStore {
    private const val FILE = "tachyo_usage"
    private const val KEEP_DAYS = 90

    /** Same format as Dart dayKey(): local yyyy-MM-dd. */
    fun dayKey(date: Date = Date()): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)

    @Synchronized
    fun add(context: Context, date: String, delta: UsageRecord) {
        if (delta.isEmpty) return
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val next = UsageRecord.decode(date, prefs.getString(date, null)) + delta
        val edit = prefs.edit().putString(date, next.encode())
        val keys = (prefs.all.keys + date).toSortedSet().toList()
        if (keys.size > KEEP_DAYS) keys.take(keys.size - KEEP_DAYS).forEach { edit.remove(it) }
        edit.apply()
    }

    @Synchronized
    fun get(context: Context, date: String): UsageRecord =
        UsageRecord.decode(date, context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(date, null))

    /** Stored days only, newest first; Dart fills the gaps. */
    @Synchronized
    fun recent(context: Context, days: Int): List<UsageRecord> {
        val all = context.getSharedPreferences(FILE, Context.MODE_PRIVATE).all
        return all.keys.sortedDescending().take(days).map { UsageRecord.decode(it, all[it] as? String) }
    }
}
