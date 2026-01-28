package dev.pro_video_player.android

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.res.Resources
import android.content.res.TypedArray
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import dev.pro_video_player.android.ProVideoPlayerPlugin.Companion.verboseLog
import android.util.Log
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.View
import androidx.fragment.app.FragmentActivity
import androidx.mediarouter.app.MediaRouteButton
import com.google.android.gms.cast.framework.CastButtonFactory
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastState
import com.google.android.gms.cast.framework.CastStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

/**
 * Factory for creating MediaRouteButton platform views.
 */
class MediaRouteButtonViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val arguments = args as? Map<*, *>
        return MediaRouteButtonPlatformView(
            context,
            viewId,
            arguments,
            messenger
        )
    }
}

/**
 * Android platform view wrapping MediaRouteButton for Chromecast device selection.
 *
 * Provides native Chromecast device picker UI with customizable appearance.
 */
class MediaRouteButtonPlatformView(
    private val context: Context,
    private val viewId: Int,
    private val arguments: Map<*, *>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MediaRouteButtonView"
    }

    private val mediaRouteButton: MediaRouteButton
    private val channel: MethodChannel
    private var castStateListener: CastStateListener? = null
    private var castContext: CastContext? = null
    private var currentTintColor: Int? = null
    private var isFragmentActivityAvailable: Boolean = false

    init {
        channel = MethodChannel(
            messenger,
            "dev.pro_video_player.android/cast_button_$viewId"
        )
        channel.setMethodCallHandler(this)

        // MediaRouteButton requires a context with a non-transparent colorBackground.
        // Flutter Activity themes often have transparent backgrounds which cause
        // MediaRouterThemeHelper.createThemedButtonContext to throw:
        // "java.lang.IllegalArgumentException: background can not be translucent: #0"
        //
        // Solution: Try multiple context approaches and fall back if all fail.
        mediaRouteButton = createMediaRouteButton(context)

        // MediaRouteButton has internal sizing for touch targets (typically 48dp).
        // We need to constrain it to match other toolbar icons.
        // Remove all padding and set explicit layout params.
        mediaRouteButton.setPadding(0, 0, 0, 0)
        mediaRouteButton.minimumWidth = 0
        mediaRouteButton.minimumHeight = 0

        // Scale the button to match typical icon size (24dp)
        val density = context.resources.displayMetrics.density
        val targetSizePx = (24 * density).toInt()
        mediaRouteButton.layoutParams = android.widget.FrameLayout.LayoutParams(
            targetSizePx,
            targetSizePx
        )

        // Check if the activity is a FragmentActivity (required for MediaRouteButton dialog)
        val activity = getActivity(context)
        isFragmentActivityAvailable = activity is FragmentActivity

        if (!isFragmentActivityAvailable) {
            Log.w(TAG, """
                |
                |════════════════════════════════════════════════════════════════════════════════
                | CAST BUTTON DISABLED: FragmentActivity required
                |════════════════════════════════════════════════════════════════════════════════
                | The Cast button requires the MainActivity to extend FlutterFragmentActivity.
                | Current activity: ${activity?.javaClass?.name ?: "null"}
                |
                | To fix this, update your MainActivity.kt:
                |
                |   // Change this:
                |   import io.flutter.embedding.android.FlutterActivity
                |   class MainActivity: FlutterActivity()
                |
                |   // To this:
                |   import io.flutter.embedding.android.FlutterFragmentActivity
                |   class MainActivity: FlutterFragmentActivity()
                |
                | The cast button will be hidden until this is fixed.
                |════════════════════════════════════════════════════════════════════════════════
            """.trimMargin())
            mediaRouteButton.visibility = View.GONE
        }

        // Initialize with CastButtonFactory
        try {
            castContext = CastContext.getSharedInstance(context)
            CastButtonFactory.setUpMediaRouteButton(context, mediaRouteButton)

            // Set up cast state listener to track visibility/state
            castStateListener = CastStateListener { state ->
                val stateString = when (state) {
                    CastState.NO_DEVICES_AVAILABLE -> "noDevices"
                    CastState.NOT_CONNECTED -> "notConnected"
                    CastState.CONNECTING -> "connecting"
                    CastState.CONNECTED -> "connected"
                    else -> "notConnected"
                }
                channel.invokeMethod("onCastStateChanged", mapOf("state" to stateString))
                // Re-apply tint color when state changes (drawable may have changed)
                currentTintColor?.let { applyTintColor(it) }
            }
            castContext?.addCastStateListener(castStateListener!!)

        } catch (e: Exception) {
            // Cast SDK may not be available
            verboseLog("Failed to initialize CastContext: ${e.message}", TAG)
            mediaRouteButton.visibility = View.GONE
        }

        // Apply initial configuration
        configureButton(arguments)
    }

    private fun configureButton(arguments: Map<*, *>?) {
        // Configure tint color if provided
        val tintColor = arguments?.get("tintColor") as? Int
        if (tintColor != null) {
            setTintColor(tintColor)
        }

        // Configure visibility
        val alwaysVisible = arguments?.get("alwaysVisible") as? Boolean ?: false
        if (alwaysVisible) {
            @Suppress("DEPRECATION")
            mediaRouteButton.setAlwaysVisible(true)
        }
    }

    private fun setTintColor(colorValue: Int) {
        currentTintColor = colorValue
        // Apply tint immediately and also after a delay (drawable may load async)
        applyTintColor(colorValue)
        mediaRouteButton.postDelayed({ applyTintColor(colorValue) }, 100)
        mediaRouteButton.postDelayed({ applyTintColor(colorValue) }, 500)
    }

    private fun applyTintColor(colorValue: Int) {
        // Extract ARGB components - colorValue is already in ARGB format from Flutter
        val color = colorValue


        // Apply color filter to the button's drawable using reflection
        try {
            val field = MediaRouteButton::class.java.getDeclaredField("mRemoteIndicator")
            field.isAccessible = true
            val drawable = field.get(mediaRouteButton) as? android.graphics.drawable.Drawable
            if (drawable != null) {
                val mutatedDrawable = drawable.mutate()
                mutatedDrawable.setTint(color)
                // Force update the drawable
                mediaRouteButton.setRemoteIndicatorDrawable(mutatedDrawable)
            } else {
                // Try to set tint on the button directly using CompoundDrawable approach
                applyTintViaDrawableState(color)
            }
        } catch (e: Exception) {
            applyTintViaDrawableState(color)
        }
    }

    private fun applyTintViaDrawableState(color: Int) {
        try {
            // Use foreground tint as alternative
            mediaRouteButton.foregroundTintList = android.content.res.ColorStateList.valueOf(color)
            mediaRouteButton.invalidate()
        } catch (_: Exception) {
            // Tint application failed - not critical
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setTintColor" -> {
                val color = call.argument<Int>("color")
                if (color != null) {
                    setTintColor(color)
                }
                result.success(null)
            }
            "setAlwaysVisible" -> {
                val alwaysVisible = call.argument<Boolean>("alwaysVisible") ?: false
                @Suppress("DEPRECATION")
                mediaRouteButton.setAlwaysVisible(alwaysVisible)
                result.success(null)
            }
            "showDialog" -> {
                // Programmatically trigger the route picker dialog
                if (!isFragmentActivityAvailable) {
                    Log.w(TAG, "Cannot show cast dialog: MainActivity must extend FlutterFragmentActivity")
                    result.error("FRAGMENT_ACTIVITY_REQUIRED",
                        "Cast dialog requires MainActivity to extend FlutterFragmentActivity", null)
                    return
                }
                mediaRouteButton.performClick()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView(): View = mediaRouteButton

    override fun dispose() {
        // Remove cast state listener
        castStateListener?.let { listener ->
            castContext?.removeCastStateListener(listener)
        }
        castStateListener = null
        castContext = null

        channel.setMethodCallHandler(null)
    }

    /**
     * Creates a MediaRouteButton, trying multiple context approaches to work around
     * the "background can not be translucent" error from MediaRouterThemeHelper.
     *
     * The key insight from Stack Overflow is that MediaRouteButton REQUIRES an AppCompat-based
     * theme (not Material or DeviceDefault). The applicationContext doesn't have AppCompat
     * initialization, so we must use the Activity context with an AppCompat theme overlay.
     *
     * See: https://stackoverflow.com/questions/46811254
     */
    private fun createMediaRouteButton(context: Context): MediaRouteButton {
        // List of context approaches to try, in order of preference
        // KEY: Use activity context (not applicationContext) with AppCompat themes
        val contextAttempts = listOf(
            // Attempt 1: Activity context with our Dark AppCompat theme (white icons on dark background)
            // This should work for video player UI which typically has dark controls background
            {
                ContextThemeWrapper(context, R.style.Theme_MediaRouteButton_Dark).also {
                    it.theme.applyStyle(R.style.Theme_MediaRouteButton_Dark, true)
                }
            },
            // Attempt 2: Activity context with our Light AppCompat-based theme
            {
                ContextThemeWrapper(context, R.style.Theme_MediaRouteButton).also {
                    it.theme.applyStyle(R.style.Theme_MediaRouteButton, true)
                }
            },
            // Attempt 3: Activity context with Theme.AppCompat.NoActionBar (dark variant)
            // AppCompat themes are REQUIRED for MediaRouteButton per Stack Overflow solutions
            {
                ContextThemeWrapper(context, androidx.appcompat.R.style.Theme_AppCompat_NoActionBar)
            },
            // Attempt 4: Activity context with Theme.AppCompat.Light.NoActionBar
            {
                ContextThemeWrapper(context, androidx.appcompat.R.style.Theme_AppCompat_Light_NoActionBar)
            },
            // Attempt 5: Application context with our custom theme (fallback)
            {
                ContextThemeWrapper(context.applicationContext, R.style.Theme_MediaRouteButton_Dark).also {
                    it.theme.applyStyle(R.style.Theme_MediaRouteButton_Dark, true)
                }
            },
            // Attempt 6: Original context as final fallback
            { context }
        )

        for (createContext in contextAttempts) {
            try {
                val attemptContext = createContext()
                return MediaRouteButton(attemptContext)
            } catch (e: IllegalArgumentException) {
                if (e.message?.contains("background can not be translucent") != true) {
                    throw e // Re-throw non-theme related errors
                }
                // Continue to next attempt for transparent background theme issue
            }
        }

        // If all attempts fail, throw the original error
        throw IllegalArgumentException("Failed to create MediaRouteButton: all context approaches failed due to transparent background theme issue")
    }

    /**
     * Extracts the Activity from a Context, unwrapping ContextWrappers if necessary.
     */
    private fun getActivity(context: Context): Activity? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) {
                return ctx
            }
            ctx = ctx.baseContext
        }
        return null
    }
}
