import Foundation

/// Result of a finished subprocess.
public struct ProcessResult {
    public let stdout: Data
    public let stderr: Data
    public let terminationStatus: Int32

    public var stdoutString: String { String(data: stdout, encoding: .utf8) ?? "" }
    public var stderrString: String { String(data: stderr, encoding: .utf8) ?? "" }
    public var succeeded: Bool { terminationStatus == 0 }
}

/// Runs subprocesses without deadlocking on their output.
///
/// A pipe holds about 64 kB. The obvious sequence - `waitUntilExit()` and then
/// `readDataToEndOfFile()` - hangs forever as soon as the child writes more than
/// that, because the child blocks on `write` while we block on `wait`. Reading
/// stdout fully before touching stderr has the same problem in the other
/// direction: tools that log progress to stderr (samtools, bwa, STAR, and `du`
/// reporting "Permission denied") fill that pipe while we are still draining
/// stdout.
///
/// Both pipes are therefore drained concurrently, and the process is reaped only
/// after both readers have reached EOF.
public enum ProcessRunner {
    /// Storage the two reader threads write into. Each field is written by
    /// exactly one thread, and the dispatch group's completion establishes the
    /// ordering before either is read.
    private final class Output: @unchecked Sendable {
        var stdout = Data()
        var stderr = Data()
    }

    /// Run `executableURL` and return its output.
    ///
    /// - Parameter onStart: called right after the process is launched, e.g. to
    ///   keep a handle for cancelling it. Runs on the calling thread.
    public static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        onStart: ((Process) -> Void)? = nil
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        onStart?(process)

        let output = Output()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "se.flashbrowse.process-reader", attributes: .concurrent)

        queue.async(group: group) {
            output.stdout = outPipe.fileHandleForReading.readDataToEndOfFile()
        }
        queue.async(group: group) {
            output.stderr = errPipe.fileHandleForReading.readDataToEndOfFile()
        }
        group.wait()

        process.waitUntilExit()

        return ProcessResult(
            stdout: output.stdout,
            stderr: output.stderr,
            terminationStatus: process.terminationStatus
        )
    }
}
