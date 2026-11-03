import Foundation
import Dispatch

@_silgen_name("configureBundleFixture")
func configure(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer, _ c: UnsafeRawPointer,
               _ d: UnsafeRawPointer, _ e: UnsafeRawPointer, _ f: UnsafeRawPointer,
               _ g: UnsafeRawPointer, _ h: UnsafeRawPointer)
@_silgen_name("checkBundleFixture")
func check(_ key: UnsafeRawPointer, _ expected: Int32)
@_silgen_name("finishBundleFixture") func finish()
final class Root {}
final class Derived: NSObject {}
final class Dynamic {}
final class Unresolved {}
final class Invalid {}
final class Concurrent {}
final class Late {}
func pointer(_ type: AnyClass) -> UnsafeRawPointer { unsafeBitCast(type, to: UnsafeRawPointer.self) }

@main struct Test {
    static func main() {
        configure(pointer(Root.self), pointer(Derived.self), pointer(NSObject.self),
                  pointer(Dynamic.self), pointer(Unresolved.self), pointer(Invalid.self),
                  pointer(Concurrent.self), pointer(Late.self))
        check(pointer(Root.self), 1)
        check(pointer(Derived.self), 1)
        check(pointer(NSObject.self), 2)
        check(pointer(Dynamic.self), 1)
        check(pointer(Unresolved.self), 1)
        check(pointer(Invalid.self), 1)
        DispatchQueue.concurrentPerform(iterations: 16000) { _ in check(pointer(Concurrent.self), 2) }
        finish()
    }
}
