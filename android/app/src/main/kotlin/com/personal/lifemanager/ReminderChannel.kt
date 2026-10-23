package com.personal.lifemanager

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** The Dart side of task reminders, the share target and notification taps. */
class ReminderChannel(private val activity: FragmentActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "com.personal.lifemanager/reminders"
        const val PERMISSION_REQUEST = 7301
    }

    private var pendingPermission: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val c = activity.applicationContext
        when (call.method) {
            "status" -> result.success(
                mapOf(
                    "notifications" to NotificationManagerCompat.from(c).areNotificationsEnabled(),
                    "exact" to Alarms.canExact(c),
                ),
            )
            "requestNotifications" -> requestNotifications(result)
            "openExactAlarmSettings" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        activity.startActivity(
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${c.packageName}")),
                        )
                    }
                } catch (_: Exception) {
                    // No settings screen to open; the in-app note stays.
                }
                result.success(null)
            }
            "schedule" -> {
                val id = call.argument<Int>("id")
                val at = call.argument<Number>("at")?.toLong()
                if (id == null || at == null) {
                    result.error("failed", null, null)
                    return
                }
                val item = JSONObject()
                    .put("at", at)
                    .put("fires", 0)
                    .put("title", call.argument<String>("title") ?: "")
                    .put("done", call.argument<String>("done") ?: "Done")
                    .put("snooze10", call.argument<String>("snooze10") ?: "10 min")
                    .put("snooze1h", call.argument<String>("snooze1h") ?: "1 h")
                    .put("channel", call.argument<String>("channel") ?: "Tasks")
                ReminderStore.put(c, id, item)
                Alarms.schedule(c, id, at)
                result.success(null)
            }
            "cancel" -> {
                val id = call.argument<Int>("id")
                if (id != null) {
                    Alarms.cancel(c, id)
                    ReminderStore.remove(c, id)
                }
                result.success(null)
            }
            "scheduledIds" -> result.success(ReminderStore.items(c).keys().asSequence().map { it.toInt() }.toList())
            "takeDoneActions" -> result.success(ReminderStore.takeDone(c))
            "takeOpenTask" -> result.success(ReminderStore.takeOpenTask(c))
            "takeSharedText" -> result.success(ReminderStore.takeShared(c))
            else -> result.notImplemented()
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(NotificationManagerCompat.from(activity).areNotificationsEnabled())
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }
}
