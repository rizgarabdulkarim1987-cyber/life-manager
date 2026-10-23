package com.personal.lifemanager

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth's BiometricPrompt, and by the vault's.
class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val EXTRA_OPEN_TASK = "plm_open_task"
    }

    private var reminders: ReminderChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep money and vault screens out of screenshots, screen recording and the recents thumbnail.
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        stash(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stash(intent)
    }

    /** Remembers a shared text or a tapped reminder for Dart to pick up (it never reaches a log). */
    private fun stash(intent: Intent?) {
        if (intent == null) return
        if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let { ReminderStore.setShared(applicationContext, it) }
            intent.removeExtra(Intent.EXTRA_TEXT)
        }
        val task = intent.getIntExtra(EXTRA_OPEN_TASK, -1)
        if (task >= 0) {
            ReminderStore.setOpenTask(applicationContext, task)
            intent.removeExtra(EXTRA_OPEN_TASK)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VaultChannel.NAME)
            .setMethodCallHandler(VaultChannel(this))
        val channel = ReminderChannel(this)
        reminders = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ReminderChannel.NAME)
            .setMethodCallHandler(channel)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        reminders?.onPermissionResult(requestCode, grantResults)
    }
}
