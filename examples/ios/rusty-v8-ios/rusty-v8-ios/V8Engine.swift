import Foundation

public final class V8Engine {
    private static var platformInitialized = false

    private var handle: UnsafeMutableRawPointer

    public init() {
        if !V8Engine.platformInitialized {
            v8_bridge_init()
            V8Engine.platformInitialized = true
        }
        handle = v8_bridge_engine_new()
    }

    deinit {
        v8_bridge_engine_free(handle)
    }

    public func reset() {
        v8_bridge_engine_free(handle)
        handle = v8_bridge_engine_new()
    }

    public func eval(_ code: String) -> (success: Bool, output: String) {
        let result = code.withCString { cStr in
            v8_bridge_engine_eval(handle, cStr)
        }
        defer { v8_bridge_result_free(result.data) }

        let output = result.data != nil
            ? String(cString: result.data)
            : ""
        return (result.success, output)
    }
}
