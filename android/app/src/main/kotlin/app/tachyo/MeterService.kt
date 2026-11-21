package app.tachyo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Foreground service that draws the live speed as the status-bar icon and
 * records per-day usage while it runs. Survives the UI being closed; restarted
 * after reboot by BootReceiver when enabled.
 */
class MeterService : Service() {
    companion object {
        const val CHANNEL_ID = "tachyo_meter_v2"
        const val NOTIFICATION_ID = 4201
        private const val FLUSH_EVERY_TICKS = 10

        @Volatile
        var running = false
            private set

        fun start(context: Context) {
            context.startForegroundService(Intent(context, MeterService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MeterService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var last: Counters? = null
    private var pending = UsageRecord("")
    private var pendingDate = UsageStore.dayKey()
    private var ticks = 0
    private val tickRunnable = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, if (isInteractive()) 1000L else 5000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val first = buildNotification(0.0, 0.0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, first, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, first)
        }
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.removeCallbacks(tickRunnable)
        handler.post(tickRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        flush()
        running = false
        super.onDestroy()
    }

    private fun isInteractive(): Boolean =
        (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive

    private fun tick() {
        val now = TrafficReader.read()
        val prev = last
        last = now
        val today = UsageStore.dayKey()
        if (today != pendingDate) {
            flush() // midnight: close out yesterday before counting today
            pendingDate = today
        }
        if (prev == null) return
        val dt = now.timeMs - prev.timeMs
        val dRx = now.rx - prev.rx
        val dTx = now.tx - prev.tx
        if (dt <= 0 || dRx < 0 || dTx < 0) return // counter reset: drop this interval

        val mRx = (now.mobileRx - prev.mobileRx).coerceAtLeast(0)
        val mTx = (now.mobileTx - prev.mobileTx).coerceAtLeast(0)
        pending += UsageRecord(
            pendingDate,
            wifiRx = (dRx - mRx).coerceAtLeast(0),
            wifiTx = (dTx - mTx).coerceAtLeast(0),
            mobileRx = mRx,
            mobileTx = mTx,
        )
        if (++ticks % FLUSH_EVERY_TICKS == 0) flush()

        // Screen off: keep counting usage, skip redrawing the notification.
        if (!isInteractive()) return
        val down = dRx * 1000.0 / dt
        val up = dTx * 1000.0 / dt
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildNotification(down, up))
    }

    private fun flush() {
        if (!pending.isEmpty) UsageStore.add(this, pendingDate, pending)
        pending = UsageRecord(pendingDate)
    }

    private fun createChannel() {
        val nm = getSystemService(NotificationManager::class.java)
        // v1 used IMPORTANCE_LOW, whose icons Android hides from the status bar.
        nm.deleteNotificationChannel("tachyo_meter")
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        // DEFAULT keeps the icon in the status bar; sound and vibration are off
        // and setOnlyAlertOnce prevents heads-up, so it never interrupts.
        val channel = NotificationChannel(CHANNEL_ID, "Speed meter", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Live network speed in the status bar"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(down: Double, up: Double): Notification {
        val bits = Prefs.unitBits(this)
        val scale = Prefs.speedScale(this)
        val (dv, du) = SpeedFormat.speed(down, bits, scale)
        val (uv, uu) = SpeedFormat.speed(up, bits, scale)
        val today = UsageStore.get(this, pendingDate) + pending
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(speedIcon(down + up, bits, scale))
            .setContentTitle("↓ $dv $du    ↑ $uv $uu")
            .setContentText(
                "Today  Mobile ${SpeedFormat.bytes(today.mobile)}  ·  Wi-Fi ${SpeedFormat.bytes(today.wifi)}",
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    /** Draws "1.2 / MB" into a white-on-transparent bitmap sized for the status bar. */
    private fun speedIcon(bytesPerSecond: Double, bits: Boolean, scale: Int): Icon {
        val (value, unit) = SpeedFormat.compact(bytesPerSecond, bits, scale)
        val size = (24 * resources.displayMetrics.density).toInt().coerceAtLeast(24)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        fun fit(text: String, maxSize: Float) {
            paint.textSize = maxSize
            val w = paint.measureText(text)
            if (w > size * 0.98f) paint.textSize = maxSize * size * 0.98f / w
        }
        // The status bar draws this icon small: fill the canvas, value on top.
        fit(value, size * 0.80f)
        canvas.drawText(value, size / 2f, size * 0.64f, paint)
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        fit(unit, size * 0.42f)
        canvas.drawText(unit, size / 2f, size * 1.0f - 1f, paint)
        return Icon.createWithBitmap(bmp)
    }
}
