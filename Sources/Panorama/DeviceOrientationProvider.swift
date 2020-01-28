import simd
public protocol DeviceOrientationProvider {
    func deviceOrientation(atTime time: TimeInterval) -> simd_quatf?
    func shouldWaitDeviceOrientation(atTime time: TimeInterval) -> Bool
}

extension DeviceOrientationProvider {
    public func waitDeviceOrientation(atTime time: TimeInterval) {
        _ = waitDeviceOrientation(atTime: time, timeout: .distantFuture)
    }

    public func waitDeviceOrientation(atTime time: TimeInterval, timeout: DispatchTime) -> DispatchTimeoutResult {
        guard deviceOrientation(atTime: time) == nil else {
            return .success
        }

        let semaphore = DispatchSemaphore(value: 0)

        let queue = DispatchQueue(label: "com.eje-c.MetalScope.DeviceOrientationProvider.waitingQueue")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10))
        timer.setEventHandler {
            if self.deviceOrientation(atTime: time) != nil {
                semaphore.signal()
            }
        }
        timer.resume()
        defer { timer.cancel() }

        return semaphore.wait(timeout: timeout)
    }
}

#if os(iOS)
import CoreMotion

extension CMMotionManager: DeviceOrientationProvider {
    public func deviceOrientation(atTime time: TimeInterval) -> simd_quatf? {
        guard let motion = deviceMotion else {
            return nil
        }

        let timeInterval = time - motion.timestamp

        guard timeInterval < 1 else {
            return nil
        }

        var rotation = simd_quatf(motion)

        if timeInterval > 0 {
            rotation.rotate(byX: Float(motion.rotationRate.x * timeInterval))
            rotation.rotate(byY: Float(motion.rotationRate.y * timeInterval))
            rotation.rotate(byZ: Float(motion.rotationRate.z * timeInterval))
        }

        let reference = simd_quatf(x: .pi / 2)

        return reference.inverse * rotation.normalized
    }

    public func shouldWaitDeviceOrientation(atTime time: TimeInterval) -> Bool {
        return isDeviceMotionActive && time - (deviceMotion?.timestamp ?? 0) > 1
    }
}

internal final class DefaultDeviceOrientationProvider: DeviceOrientationProvider {
    private static let motionManager = CMMotionManager()

    private static let instanceCountQueue = DispatchQueue(label: "com.eje-c.MetalScope.DefaultDeviceOrientationProvider.instanceCountQueue")

    private static var instanceCount: Int = 0 {
        didSet {
            let manager = motionManager

            guard manager.isDeviceMotionAvailable else {
                return
            }

            if instanceCount > 0, !manager.isDeviceMotionActive {
                manager.deviceMotionUpdateInterval = 1 / 60
                manager.startDeviceMotionUpdates()
            } else if instanceCount == 0, manager.isDeviceMotionActive {
                manager.stopDeviceMotionUpdates()
            }
        }
    }

    private static func incrementInstanceCount() {
        instanceCountQueue.async { instanceCount += 1 }
    }

    private static func decrementInstanceCount() {
        instanceCountQueue.async { instanceCount -= 1 }
    }

    init() {
        DefaultDeviceOrientationProvider.incrementInstanceCount()
    }

    deinit {
        DefaultDeviceOrientationProvider.decrementInstanceCount()
    }

    func deviceOrientation(atTime time: TimeInterval) -> simd_quatf? {
        return DefaultDeviceOrientationProvider.motionManager.deviceOrientation(atTime: time)
    }

    func shouldWaitDeviceOrientation(atTime time: TimeInterval) -> Bool {
        return DefaultDeviceOrientationProvider.motionManager.shouldWaitDeviceOrientation(atTime: time)
    }
}
#endif
