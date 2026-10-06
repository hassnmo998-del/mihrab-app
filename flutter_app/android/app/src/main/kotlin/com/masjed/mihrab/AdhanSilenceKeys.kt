package com.masjed.mihrab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * While the adhan sounds, pressing volume up, volume down or the power key silences it
 * at once — like an incoming call — with the app closed and the screen locked too.
 *
 * Volume keys: an active media session with a "remote" volume gets every key press as
 * [VolumeProvider.onAdjustVolume], whatever the current volume is (a plain volume
 * listener hears nothing when the volume is already at its end). A volume-changed
 * broadcast covers phones that do not route the keys to the session.
 *
 * Power key: it has no event of its own, only the screen going off or on.
 *  - Screen on: it is kept on (dim) while the adhan plays, so it cannot time out and a
 *    screen-off can only be the user.
 *  - Screen off: a screen-on is the user waking the phone — except in the first moments,
 *    when the adhan notification itself may wake it. That wake is not a key press; the
 *    screen is then kept on like above.
 */
internal object AdhanSilenceKeys {
    private const val TAG = "AdhanSilenceKeys"
    private const val VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION"
    private const val EXTRA_STREAM = "android.media.EXTRA_VOLUME_STREAM_TYPE"
    private const val EXTRA_VALUE = "android.media.EXTRA_VOLUME_STREAM_VALUE"
    private const val EXTRA_PREVIOUS = "android.media.EXTRA_PREV_VOLUME_STREAM_VALUE"

    /** A screen-on this soon after the adhan starts is its own notification waking the phone. */
    private const val SYSTEM_WAKE_WINDOW_MS = 3000L

    /** Volume changes this soon after the start are the system settling, not a key. */
    private const val VOLUME_SETTLE_MS = 1000L

    private val userStreams = setOf(
        AudioManager.STREAM_ALARM,
        AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_RING,
        AudioManager.STREAM_NOTIFICATION,
    )

    private var appContext: Context? = null
    private var session: MediaSession? = null
    private var receiver: BroadcastReceiver? = null
    private var screenLock: PowerManager.WakeLock? = null
    private var onSilence: (() -> Unit)? = null
    private var armedAt = 0L

    /** Starts listening. [silence] runs once, on the first key, after listening has stopped. */
    fun arm(context: Context, silence: () -> Unit) {
        disarm()
        val app = context.applicationContext
        appContext = app
        onSilence = silence
        armedAt = SystemClock.elapsedRealtime()

        val power = app.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (power.isInteractive) keepScreenOn(power)

        try {
            session = MediaSession(app, "MihrabAdhan").apply {
                setPlaybackState(
                    PlaybackState.Builder()
                        .setState(PlaybackState.STATE_PLAYING, 0L, 1f)
                        .build()
                )
                setPlaybackToRemote(object : VolumeProvider(VOLUME_CONTROL_RELATIVE, 15, 8) {
                    // 0 is the key being released
                    override fun onAdjustVolume(direction: Int) {
                        if (direction != 0) fire("volume key")
                    }

                    override fun onSetVolumeTo(volume: Int) = fire("volume slider")
                })
                isActive = true
            }
        } catch (e: Exception) {
            Log.w(TAG, "No media session for the volume keys", e)
        }

        val screenAndVolume = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent?) {
                val sinceStart = SystemClock.elapsedRealtime() - armedAt
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> fire("power key, screen off")
                    Intent.ACTION_SCREEN_ON ->
                        if (sinceStart < SYSTEM_WAKE_WINDOW_MS) {
                            keepScreenOn(power)
                        } else {
                            fire("power key, screen on")
                        }
                    VOLUME_CHANGED -> {
                        val stream = intent.getIntExtra(EXTRA_STREAM, -1)
                        val changed = intent.getIntExtra(EXTRA_VALUE, -1) !=
                            intent.getIntExtra(EXTRA_PREVIOUS, -1)
                        if (sinceStart > VOLUME_SETTLE_MS && changed && stream in userStreams) {
                            fire("volume changed")
                        }
                    }
                }
            }
        }
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(VOLUME_CHANGED)
            }
            // All three are sent by the system, which reaches a non-exported receiver
            ContextCompat.registerReceiver(app, screenAndVolume, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiver = screenAndVolume
        } catch (e: Exception) {
            Log.w(TAG, "Could not listen for the power and volume keys", e)
        }
    }

    /** Stops listening. Safe to call when nothing is armed. */
    fun disarm() {
        onSilence = null
        receiver?.let {
            try {
                appContext?.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        receiver = null
        session?.let {
            try {
                it.isActive = false
                it.release()
            } catch (_: Exception) {
            }
        }
        session = null
        screenLock?.let {
            try {
                if (it.isHeld) it.release()
            } catch (_: Exception) {
            }
        }
        screenLock = null
        appContext = null
    }

    private fun fire(reason: String) {
        val silence = onSilence ?: return
        Log.d(TAG, "Adhan silenced by $reason")
        disarm()
        silence()
    }

    /** Keeps a lit screen from timing out; it does not wake a dark one. */
    @Suppress("DEPRECATION")
    private fun keepScreenOn(power: PowerManager) {
        if (screenLock?.isHeld == true) return
        try {
            screenLock = power.newWakeLock(PowerManager.SCREEN_DIM_WAKE_LOCK, "Mihrab:AdhanScreen").apply {
                setReferenceCounted(false)
                acquire(10 * 60 * 1000L)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not keep the screen on", e)
        }
    }
}
