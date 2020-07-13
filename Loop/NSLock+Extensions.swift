import Foundation

final class RecursiveLock {
    let lock = NSRecursiveLock()
    private var isLockAcquired = false

    init() {}

    /// Try to acquire the lock, perform the given action, and return whether or not the action is successful.
    ///
    /// - returns: The boolean flag indicating successfulness as returned by `action`. If the lock cannot be acquired,
    ///            `false` is returned.
    @inlinable
    func tryPerform(_ action: (_ isReentrant: Bool) -> Bool) -> Bool {
        if lock.try() {
            defer { lock.unlock() }
            return run(action)
        }

        return false
    }

    /// Acquire the lock, and perform the given action. If the lock is contested, wait until it is free.
    ///
    /// - returns: Pass through the value produced by `action`.
    @inlinable
    func perform<Result>(_ action: (_ isReentrant: Bool) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return run(action)
    }

    private func run<Result>(_ action: (_ isReentrant: Bool) -> Result) -> Result {
        if isLockAcquired {
            return action(true)
        } else {
            isLockAcquired = true
            defer { isLockAcquired = false }
            return action(false)
        }
    }
}
