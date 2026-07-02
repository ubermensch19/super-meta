import ExpoModulesCore
import UIKit

#if canImport(MWDATCore)
import MWDATCore
import MWDATCamera
#endif

// Expo Module bridge over Meta's Wearables DAT SDK. Ports the logic proven in the
// native app's GlassesService (Packages/GlassesKit). All SDK usage is guarded with
// `#if canImport(MWDATCore)` so the module still compiles — and cleanly reports
// `unavailable` — when the SDK isn't linked (e.g. before the SPM package is added,
// or on the simulator where there are no glasses).

public class ExpoGlassesModule: Module {
  private let core = GlassesCore()
  // Snapshot cached off the main actor so the synchronous getStatus() can serve it.
  nonisolated(unsafe) private var lastStatus: [String: Any] = [
    "isAvailable": false, "registration": "unavailable",
    "hasActiveDevice": false, "streamState": "stopped",
  ]

  public func definition() -> ModuleDefinition {
    Name("ExpoGlasses")
    Events("onStatus", "onFrame")

    OnCreate {
      Task { @MainActor in
        self.core.onStatus = { [weak self] status in
          self?.lastStatus = status
          self?.sendEvent("onStatus", status)
        }
        self.core.onFrame = { [weak self] frame in
          self?.sendEvent("onFrame", frame)
        }
        self.core.configure()
      }
    }

    Function("getStatus") { self.lastStatus }

    AsyncFunction("startRegistration") { (promise: Promise) in
      Task { @MainActor in self.core.startRegistration(); promise.resolve(nil) }
    }
    AsyncFunction("startUnregistration") { (promise: Promise) in
      Task { @MainActor in self.core.startUnregistration(); promise.resolve(nil) }
    }
    Function("handleUrl") { (url: String) in
      Task { @MainActor in if let u = URL(string: url) { self.core.handleUrl(u) } }
    }
    AsyncFunction("startStreaming") { (promise: Promise) in
      Task { @MainActor in await self.core.startStreaming(); promise.resolve(nil) }
    }
    AsyncFunction("stopStreaming") { (promise: Promise) in
      Task { @MainActor in await self.core.stopStreaming(); promise.resolve(nil) }
    }
    AsyncFunction("capturePhoto") { (promise: Promise) in
      Task { @MainActor in
        do { promise.resolve(try await self.core.capturePhotoBase64()) }
        catch { promise.reject("E_CAPTURE", error.localizedDescription) }
      }
    }
  }
}

/// Mirrors GlassesService. Kept UI-framework-free so it lives inside the module.
@MainActor
final class GlassesCore {
  // Constructed from the module's nonisolated context; the stored-property
  // defaults are all trivial, so an empty nonisolated init is safe.
  nonisolated init() {}

  var onStatus: (([String: Any]) -> Void)?
  var onFrame: (([String: Any]) -> Void)?

  private(set) var isAvailable = false
  private(set) var registration = "unavailable"
  private(set) var hasActiveDevice = false
  private(set) var streamState = "stopped"
  private(set) var lastError: String?
  private var wantsStreaming = false

  func statusDict() -> [String: Any] {
    var d: [String: Any] = [
      "isAvailable": isAvailable,
      "registration": registration,
      "hasActiveDevice": hasActiveDevice,
      "streamState": streamState,
    ]
    if let lastError { d["lastError"] = lastError }
    return d
  }

  private func emit() { onStatus?(statusDict()) }

  #if canImport(MWDATCore)
  private var wearables: WearablesInterface?
  private var selector: AutoDeviceSelector?
  private var session: StreamSession?
  private var stateToken: AnyListenerToken?
  private var frameToken: AnyListenerToken?
  private var deviceTask: Task<Void, Never>?
  private var registrationTask: Task<Void, Never>?
  private var photoContinuation: CheckedContinuation<Data, Error>?
  private var photoToken: AnyListenerToken?
  private var isProcessingFrame = false
  nonisolated(unsafe) private var foregroundToken: NSObjectProtocol?
  private static var didConfigure = false

  func configure() {
    if !Self.didConfigure {
      do { try Wearables.configure(); Self.didConfigure = true }
      catch { isAvailable = false; registration = "notRegistered"; lastError = "SDK unavailable"; emit(); return }
    }
    let w = Wearables.shared
    let sel = AutoDeviceSelector(wearables: w)
    let cfg = StreamSessionConfig(videoCodec: .raw, resolution: .medium, frameRate: 24)
    let s = StreamSession(streamSessionConfig: cfg, deviceSelector: sel)
    wearables = w; selector = sel; session = s
    isAvailable = true

    registration = map(w.registrationState)
    registrationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await state in w.registrationStateStream() { self.registration = self.map(state); self.emit() }
    }
    deviceTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await device in sel.activeDeviceStream() {
        self.hasActiveDevice = (device != nil); self.emit()
        if device != nil, self.wantsStreaming, self.streamState != "streaming" { await self.startStreaming() }
      }
    }
    stateToken = s.statePublisher.listen { [weak self] state in
      Task { @MainActor [weak self] in self?.updateStreamState(state) }
    }
    frameToken = s.videoFramePublisher.listen { [weak self] frame in
      Task { @MainActor [weak self] in self?.handleFrame(frame) }
    }
    photoToken = s.photoDataPublisher.listen { [weak self] photo in
      Task { @MainActor [weak self] in
        self?.photoContinuation?.resume(returning: photo.data); self?.photoContinuation = nil
      }
    }
    foregroundToken = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.wantsStreaming, self.streamState != "streaming" else { return }
        await self.startStreaming()
      }
    }
    emit()
  }

  func startRegistration() {
    guard let wearables, registration != "registering", registration != "registered" else { return }
    Task { do { try await wearables.startRegistration() } catch { setError(error.localizedDescription) } }
  }

  func startUnregistration() {
    guard let wearables else { return }
    Task { try? await wearables.startUnregistration() }
  }

  func handleUrl(_ url: URL) {
    guard let wearables else { return }
    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    guard comps?.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true else { return }
    Task { _ = try? await wearables.handleUrl(url) }
  }

  func startStreaming() async {
    guard let wearables, let session else { return }
    wantsStreaming = true
    do {
      let status = try await wearables.checkPermissionStatus(Permission.camera)
      if status != .granted {
        guard try await wearables.requestPermission(Permission.camera) == .granted else {
          setError("Camera permission denied"); return
        }
      }
      await session.start()
    } catch { setError(error.localizedDescription) }
  }

  func stopStreaming() async {
    wantsStreaming = false
    await session?.stop()
  }

  func capturePhotoBase64(timeout: TimeInterval = 8) async throws -> String {
    guard let session else { throw NSError(domain: "glasses", code: 1) }
    photoContinuation?.resume(throwing: NSError(domain: "glasses", code: 2))
    photoContinuation = nil
    let data: Data = try await withCheckedThrowingContinuation { c in
      self.photoContinuation = c
      session.capturePhoto(format: .jpeg)
      Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        if let p = self?.photoContinuation { p.resume(throwing: NSError(domain: "glasses", code: 3)); self?.photoContinuation = nil }
      }
    }
    return data.base64EncodedString()
  }

  private func handleFrame(_ frame: VideoFrame) {
    guard !isProcessingFrame else { return }
    isProcessingFrame = true; defer { isProcessingFrame = false }
    guard let image = frame.makeUIImage(), let jpeg = image.jpegData(compressionQuality: 0.7) else { return }
    onFrame?(["base64": jpeg.base64EncodedString(), "width": image.size.width, "height": image.size.height])
  }

  private func updateStreamState(_ state: StreamSessionState) {
    switch state {
    case .stopped: streamState = "stopped"
    case .streaming: streamState = "streaming"
    case .waitingForDevice, .starting, .stopping, .paused: streamState = "waiting"
    default: streamState = "error"
    }
    emit()
  }

  private func map(_ state: RegistrationState) -> String {
    if state == .registered { return "registered" }
    if state == .registering { return "registering" }
    return "notRegistered"
  }
  #else
  // SDK not linked: everything degrades to the unavailable path.
  func configure() { isAvailable = false; registration = "notRegistered"; emit() }
  func startRegistration() {}
  func startUnregistration() {}
  func handleUrl(_ url: URL) {}
  func startStreaming() async {}
  func stopStreaming() async {}
  func capturePhotoBase64(timeout: TimeInterval = 8) async throws -> String {
    throw NSError(domain: "glasses", code: 0, userInfo: [NSLocalizedDescriptionKey: "Glasses SDK not available"])
  }
  #endif

  private func setError(_ message: String) { lastError = message; emit() }
}
