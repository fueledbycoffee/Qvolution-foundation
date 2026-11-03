import Foundation
import Dispatch

final class CraftBundleRoot {}
final class CraftBundleDerived: NSObject {}
final class CraftBundleConcurrent {}

@main struct Test {
    static func main() {
        let main = Bundle.main
        precondition(Bundle(for: CraftBundleRoot.self) === main)
        precondition(Bundle(for: CraftBundleDerived.self) === main)
        let framework: Bundle? = Bundle(for: NSObject.self)
        precondition(framework !== main)
        precondition(framework?.bundlePath.hasSuffix("Foundation.framework") == true)
        precondition(Bundle(for: NSObject.self) === framework)
        DispatchQueue.concurrentPerform(iterations: 16000) { _ in
            precondition(Bundle(for: CraftBundleConcurrent.self) === main)
            precondition(Bundle(for: CraftBundleRoot.self) === main)
            precondition(Bundle(for: NSObject.self) === framework)
        }
        print("PASS: bundleForClass Swift root, NSObject subclass, framework identity, concurrency")
    }
}
