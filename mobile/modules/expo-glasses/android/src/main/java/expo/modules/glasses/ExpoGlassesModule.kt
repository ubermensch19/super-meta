package expo.modules.glasses

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.startStreamSession
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.core.types.RegistrationState

// Android bridge over Meta's Wearables DAT SDK, ported from turbometa's
// WearablesViewModel and matched to the iOS module's JS surface. This compiles
// only once the DAT Maven artifacts resolve, which needs a GitHub token with
// read:packages (see the module README) — so it's built in a dev build, never Expo Go.
class ExpoGlassesModule : Module() {
  private val scope = CoroutineScope(Dispatchers.Main)
  private val selector = AutoDeviceSelector()
  private var session: StreamSession? = null
  private var streamJobs = mutableListOf<Job>()

  private var isAvailable = false
  private var registration = "unavailable"
  private var hasActiveDevice = false
  private var streamState = "stopped"
  private var wantsStreaming = false
  private var lastFrame: Bitmap? = null

  private fun status(): Map<String, Any> = mapOf(
    "isAvailable" to isAvailable,
    "registration" to registration,
    "hasActiveDevice" to hasActiveDevice,
    "streamState" to streamState,
  )

  override fun definition() = ModuleDefinition {
    Name("ExpoGlasses")
    Events("onStatus", "onFrame")

    OnCreate {
      val context = appContext.reactContext ?: return@OnCreate
      try {
        Wearables.initialize(context)
        isAvailable = true
        monitor()
      } catch (e: Throwable) {
        isAvailable = false
        registration = "notRegistered"
      }
      sendEvent("onStatus", status())
    }

    Function("getStatus") { status() }

    AsyncFunction("startRegistration") { promise: Promise ->
      if (registration != "registering" && registration != "registered") {
        appContext.currentActivity?.let { Wearables.startRegistration(it) }
      }
      promise.resolve(null)
    }
    AsyncFunction("startUnregistration") { promise: Promise ->
      appContext.currentActivity?.let { Wearables.startUnregistration(it) }
      promise.resolve(null)
    }
    // The Meta AI OAuth callback is delivered to the Activity's intent on Android,
    // so there's no explicit URL to hand back here; kept for API parity with iOS.
    Function("handleUrl") { _: String -> }

    AsyncFunction("startStreaming") { promise: Promise ->
      wantsStreaming = true
      scope.launch { startStreaming(); promise.resolve(null) }
    }
    AsyncFunction("stopStreaming") { promise: Promise ->
      wantsStreaming = false
      stopStreaming()
      promise.resolve(null)
    }
    AsyncFunction("capturePhoto") { promise: Promise ->
      // Return the latest streamed frame as JPEG. (A dedicated still-capture API
      // exists on the session; the latest frame is the low-risk cross-platform path.)
      val bmp = lastFrame
      if (bmp == null) promise.reject("E_CAPTURE", "No frame available", null)
      else promise.resolve(jpegBase64(bmp))
    }

    OnDestroy { stopStreaming(); scope.coroutineContext[Job]?.cancel() }
  }

  private fun monitor() {
    scope.launch {
      selector.activeDevice(Wearables.devices).collect { device ->
        hasActiveDevice = device != null
        emitStatus()
        if (device != null && wantsStreaming && streamState != "streaming") startStreaming()
      }
    }
    scope.launch {
      Wearables.registrationState.collect { state ->
        registration = when (state) {
          is RegistrationState.Registered -> "registered"
          is RegistrationState.Registering -> "registering"
          else -> "notRegistered"
        }
        emitStatus()
      }
    }
  }

  private suspend fun startStreaming() {
    if (Wearables.checkPermissionStatus(Permission.CAMERA) != PermissionStatus.Granted) {
      // Permission is requested through the Activity's permission launcher; bail
      // until granted rather than crashing.
      return
    }
    stopStreaming()
    val s = Wearables.startStreamSession(selector, StreamConfiguration(VideoQuality.MEDIUM, 24))
    session = s
    streamJobs += scope.launch { s.videoStream.collect { handleFrame(it) } }
    streamJobs += scope.launch {
      s.state.collect { st ->
        streamState = when (st) {
          StreamSessionState.Streaming -> "streaming"
          StreamSessionState.Stopped -> "stopped"
          else -> "waiting"
        }
        emitStatus()
      }
    }
  }

  private fun stopStreaming() {
    streamJobs.forEach { it.cancel() }
    streamJobs.clear()
    session?.stop()
    session = null
  }

  private fun handleFrame(frame: VideoFrame) {
    try {
      val bmp = frame.toBitmap() ?: return
      lastFrame = bmp
      sendEvent("onFrame", mapOf("base64" to jpegBase64(bmp), "width" to bmp.width, "height" to bmp.height))
    } catch (_: Throwable) {}
  }

  // VideoFrame exposes raw bytes; decode defensively. Exact accessors are validated
  // against the SDK during the first dev build.
  private fun VideoFrame.toBitmap(): Bitmap? = try {
    val bytes = this.javaClass.getMethod("getData").invoke(this) as? ByteArray
    bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
  } catch (_: Throwable) { null }

  private fun jpegBase64(bmp: Bitmap): String {
    val out = ByteArrayOutputStream()
    bmp.compress(Bitmap.CompressFormat.JPEG, 70, out)
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
  }

  private fun emitStatus() = sendEvent("onStatus", status())
}
