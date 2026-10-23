package com.personal.lifemanager

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Task reminders without any Google service (plan Phase 4, Decision 5).
 *
 * Everything a reminder needs after a reboot lives in this file's own
 * SharedPreferences, because the encrypted database is only opened by Dart.
 * A notification's Done is queued here and applied by Dart the next time the
 * app opens. Nothing here logs.
 */
object ReminderStore {
    private const val PREFS = "plm_reminders"
    private const val ITEMS = "items"
    private const val DONE = "done_actions"
    private const val OPEN = "open_task"
    private const val SHARED = "shared_text"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun items(c: Context): JSONObject =
        try { JSONObject(prefs(c).getString(ITEMS, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }

    @Synchronized
    fun put(c: Context, id: Int, item: JSONObject) {
        val all = items(c)
        all.put(id.toString(), item)
        prefs(c).edit().putString(ITEMS, all.toString()).apply()
    }

    @Synchronized
    fun remove(c: Context, id: Int) {
        val all = items(c)
        all.remove(id.toString())
        prefs(c).edit().putString(ITEMS, all.toString()).apply()
    }

    @Synchronized
    fun addDone(c: Context, id: Int) {
        val list = try { JSONArray(prefs(c).getString(DONE, "[]")) } catch (_: Exception) { JSONArray() }
        list.put(id)
        prefs(c).edit().putString(DONE, list.toString()).apply()
    }

    @Synchronized
    fun takeDone(c: Context): List<Int> {
        val list = try { JSONArray(prefs(c).getString(DONE, "[]")) } catch (_: Exception) { JSONArray() }
        prefs(c).edit().remove(DONE).apply()
        return (0 until list.length()).map { list.getInt(it) }
    }

    fun setOpenTask(c: Context, id: Int) = prefs(c).edit().putInt(OPEN, id).apply()

    @Synchronized
    fun takeOpenTask(c: Context): Int {
        val id = prefs(c).getInt(OPEN, -1)
        prefs(c).edit().remove(OPEN).apply()
        return id
    }

    fun setShared(c: Context, text: String) = prefs(c).edit().putString(SHARED, text.take(50_000)).apply()

    @Synchronized
    fun takeShared(c: Context): String? {
        val t = prefs(c).getString(SHARED, null)
        prefs(c).edit().remove(SHARED).apply()
        return t
    }
}

object Alarms {
    const val ACTION_FIRE = "com.personal.lifemanager.REMINDER_FIRE"
    const val ACTION_DONE = "com.personal.lifemanager.REMINDER_DONE"
    const val ACTION_SNOOZE = "com.personal.lifemanager.REMINDER_SNOOZE"
    const val EXTRA_ID = "plm_task_id"
    const val EXTRA_MINUTES = "plm_minutes"
    const val CHANNEL = "plm_tasks"

    /** Reminders that fire and are not handled repeat hourly, for at most three days. */
    const val NAG_MS = 60L * 60L * 1000L
    const val MAX_FIRES = 72

    fun canExact(c: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
    }

    private fun intentFor(c: Context, id: Int): PendingIntent {
        val i = Intent(c, ReminderReceiver::class.java).setAction(ACTION_FIRE)
            .setData(Uri.parse("plm://reminder/$id")).putExtra(EXTRA_ID, id)
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun schedule(c: Context, id: Int, atMs: Long) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = intentFor(c, id)
        try {
            if (canExact(c)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        }
    }

    fun cancel(c: Context, id: Int) {
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(intentFor(c, id))
        NotificationManagerCompat.from(c).cancel(id)
    }

    /** Puts every stored reminder back after a reboot, a clock or zone change, or an update. */
    fun rescheduleAll(c: Context) {
        val all = ReminderStore.items(c)
        val now = System.currentTimeMillis()
        for (key in all.keys()) {
            val item = all.optJSONObject(key) ?: continue
            val at = item.optLong("at", 0L)
            // A reminder missed while the phone was off fires a few seconds after boot.
            schedule(c, key.toInt(), if (at <= now) now + 5_000L else at)
        }
    }

    fun ensureChannel(c: Context, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_HIGH))
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(Alarms.EXTRA_ID, -1)
        if (id < 0) return
        val item = ReminderStore.items(context).optJSONObject(id.toString()) ?: return
        val fires = item.optInt("fires", 0) + 1

        Alarms.ensureChannel(context, item.optString("channel", "Tasks"))
        if (NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            val open = PendingIntent.getActivity(
                context, id,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(MainActivity.EXTRA_OPEN_TASK, id),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            fun action(code: Int, label: String, act: String, minutes: Int = 0): NotificationCompat.Action {
                val i = Intent(context, ReminderActionReceiver::class.java).setAction(act)
                    .setData(Uri.parse("plm://reminder/$id/$act/$minutes"))
                    .putExtra(Alarms.EXTRA_ID, id).putExtra(Alarms.EXTRA_MINUTES, minutes)
                val pi = PendingIntent.getBroadcast(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                return NotificationCompat.Action.Builder(0, label, pi).build()
            }
            val n = NotificationCompat.Builder(context, Alarms.CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_task)
                .setContentTitle(item.optString("title"))
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setContentIntent(open)
                .setAutoCancel(true)
                .addAction(action(id * 4 + 1, item.optString("done", "Done"), Alarms.ACTION_DONE))
                .addAction(action(id * 4 + 2, item.optString("snooze10", "10 min"), Alarms.ACTION_SNOOZE, 10))
                .addAction(action(id * 4 + 3, item.optString("snooze1h", "1 h"), Alarms.ACTION_SNOOZE, 60))
                .build()
            try {
                NotificationManagerCompat.from(context).notify(id, n)
            } catch (_: SecurityException) {
                // The permission was withdrawn between the check and the call.
            }
        }

        if (fires >= Alarms.MAX_FIRES) {
            ReminderStore.remove(context, id)
        } else {
            val next = System.currentTimeMillis() + Alarms.NAG_MS
            item.put("fires", fires)
            item.put("at", next)
            ReminderStore.put(context, id, item)
            Alarms.schedule(context, id, next)
        }
    }
}

class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(Alarms.EXTRA_ID, -1)
        if (id < 0) return
        when (intent.action) {
            Alarms.ACTION_DONE -> {
                Alarms.cancel(context, id)
                ReminderStore.remove(context, id)
                ReminderStore.addDone(context, id)
            }
            Alarms.ACTION_SNOOZE -> {
                val minutes = intent.getIntExtra(Alarms.EXTRA_MINUTES, 10)
                val item = ReminderStore.items(context).optJSONObject(id.toString())
                NotificationManagerCompat.from(context).cancel(id)
                if (item != null) {
                    val at = System.currentTimeMillis() + minutes * 60_000L
                    item.put("at", at)
                    item.put("fires", 0)
                    ReminderStore.put(context, id, item)
                    Alarms.schedule(context, id, at)
                }
            }
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Alarms.rescheduleAll(context)
    }
}
