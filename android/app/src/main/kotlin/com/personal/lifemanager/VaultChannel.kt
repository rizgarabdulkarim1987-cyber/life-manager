package com.personal.lifemanager

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The vault's native side (plan Phase 3, Decisions 12 and 15).
 *
 * Biometric key: AES-256-GCM in Android Keystore. Every use needs a strong
 * biometric through BiometricPrompt with a CryptoObject; the device PIN is not
 * accepted, and adding a fingerprint invalidates the key.
 *
 * Clipboard: copies are marked sensitive (EXTRA_IS_SENSITIVE, honoured from
 * Android 13) and cleared after the delay unless another app's clip replaced
 * ours. If the process dies first, the clip stays; the UI doesn't promise more.
 *
 * Errors go back to Dart as codes only (invalidated, cancelled, lockout,
 * unavailable, failed). Nothing here logs, and no message carries data.
 */
class VaultChannel(private val activity: FragmentActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "com.personal.lifemanager/vault"
        private const val KEY_ALIAS = "vault_bio_kek_v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_LENGTH = 12
        private const val TAG_BITS = 128
        private const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }

    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "bioAvailable" -> result.success(biometricAvailable())
            "bioEncrypt" -> crypt(call, result, encrypt = true)
            "bioDecrypt" -> crypt(call, result, encrypt = false)
            "bioDelete" -> {
                deleteKey()
                result.success(null)
            }
            "copySecret" -> copySecret(call, result)
            else -> result.notImplemented()
        }
    }

    private fun biometricAvailable(): Boolean =
        BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun deleteKey() {
        try {
            keyStore().deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {
            // Already gone.
        }
    }

    private fun existingKey(): SecretKey? = keyStore().getKey(KEY_ALIAS, null) as SecretKey?

    private fun createKey(): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // 0 seconds: auth for every single use, strong biometrics only.
            spec.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        } else {
            @Suppress("DEPRECATION")
            spec.setUserAuthenticationValidityDurationSeconds(-1)
        }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(spec.build())
        return gen.generateKey()
    }

    private fun crypt(call: MethodCall, result: MethodChannel.Result, encrypt: Boolean) {
        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.error("failed", null, null)
            return
        }
        if (!biometricAvailable()) {
            result.error("unavailable", null, null)
            return
        }

        val cipher: Cipher
        try {
            cipher = Cipher.getInstance(TRANSFORMATION)
            if (encrypt) {
                // Turning fingerprint unlock on always starts from a fresh key.
                deleteKey()
                cipher.init(Cipher.ENCRYPT_MODE, createKey())
            } else {
                if (data.size <= IV_LENGTH) {
                    result.error("failed", null, null)
                    return
                }
                val key = existingKey()
                if (key == null) {
                    result.error("invalidated", null, null)
                    return
                }
                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, data, 0, IV_LENGTH))
            }
        } catch (_: KeyPermanentlyInvalidatedException) {
            deleteKey()
            result.error("invalidated", null, null)
            return
        } catch (_: Exception) {
            result.error(if (encrypt) "unavailable" else "failed", null, null)
            return
        }

        val replied = AtomicBoolean(false)
        fun reply(block: () -> Unit) {
            if (replied.compareAndSet(false, true)) block()
        }

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                val c = auth.cryptoObject?.cipher
                if (c == null) {
                    reply { result.error("failed", null, null) }
                    return
                }
                try {
                    val out = if (encrypt) {
                        val sealed = c.doFinal(data)
                        c.iv + sealed
                    } else {
                        c.doFinal(data, IV_LENGTH, data.size - IV_LENGTH)
                    }
                    // The codec copies the bytes inside success(), so they can be wiped right after.
                    reply { result.success(out) }
                    out.fill(0)
                } catch (_: Exception) {
                    reply { result.error("failed", null, null) }
                } finally {
                    data.fill(0)
                }
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                val code = when (errorCode) {
                    BiometricPrompt.ERROR_USER_CANCELED,
                    BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                    BiometricPrompt.ERROR_CANCELED -> "cancelled"
                    BiometricPrompt.ERROR_LOCKOUT,
                    BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "lockout"
                    BiometricPrompt.ERROR_NO_BIOMETRICS,
                    BiometricPrompt.ERROR_HW_NOT_PRESENT,
                    BiometricPrompt.ERROR_HW_UNAVAILABLE -> "unavailable"
                    else -> "failed"
                }
                data.fill(0)
                reply { result.error(code, null, null) }
            }

            // A single unrecognised finger: the prompt stays open for another try.
            override fun onAuthenticationFailed() {}
        }

        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(call.argument<String>("title") ?: "")
            .setSubtitle(call.argument<String>("subtitle"))
            .setNegativeButtonText(call.argument<String>("cancel") ?: "Cancel")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()

        try {
            BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
                .authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (_: Exception) {
            data.fill(0)
            reply { result.error("unavailable", null, null) }
        }
    }

    private fun clipboard(): ClipboardManager =
        activity.applicationContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    private fun copySecret(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
        val label = call.argument<String>("label")
        val delay = call.argument<Number>("clearAfterMs")?.toLong() ?: 30_000L
        if (text == null || label == null) {
            result.error("failed", null, null)
            return
        }
        try {
            val clip = ClipData.newPlainText(label, text)
            clip.description.extras = PersistableBundle().apply { putBoolean(EXTRA_IS_SENSITIVE, true) }
            val cm = clipboard()
            cm.setPrimaryClip(clip)
            main.postDelayed({ clearIfOurs(cm, label) }, delay)
            result.success(null)
        } catch (_: Exception) {
            result.error("failed", null, null)
        }
    }

    /** Clears the clip unless it now carries another label. An unreadable clip (background
     *  read restrictions) is cleared too: removing a secret beats keeping a stranger's text. */
    private fun clearIfOurs(cm: ClipboardManager, label: String) {
        try {
            val current = cm.primaryClipDescription?.label?.toString()
            if (current != null && current != label) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                cm.clearPrimaryClip()
            } else {
                cm.setPrimaryClip(ClipData.newPlainText("", ""))
            }
        } catch (_: Exception) {
            // Nothing more can be done from here.
        }
    }
}
