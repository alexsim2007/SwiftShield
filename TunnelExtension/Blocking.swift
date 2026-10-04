import Foundation

func runBlocking<T>(_ operation: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = BlockingResult<T>()
    Task.detached(priority: .userInitiated) {
        do {
            box.result = .success(try await operation())
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return try box.result!.get()
}

private final class BlockingResult<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}
