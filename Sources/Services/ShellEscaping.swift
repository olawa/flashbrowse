import Foundation

// MARK: - Shell Escaping Utility

public extension String {
    /// Quote this string for safe use as a single POSIX shell word.
    ///
    /// Anything interpolated into a shell command - a local path, a remote path
    /// handed to scp, a file name from a listing - has to go through here.
    /// Without it a name containing a space becomes two arguments, and one
    /// containing `;`, `$(…)` or a backtick runs whatever it says. Remote
    /// directory names are written by other people on shared systems, so they
    /// are not trustworthy input.
    ///
    /// The string is wrapped in single quotes, where the shell treats every
    /// character literally, and embedded single quotes are closed, escaped and
    /// reopened (`'\''`) - the only way to get one inside a quoted word.
    ///
    ///     "my data.bam".shellEscaped   // 'my data.bam'
    ///     "a;rm -rf x".shellEscaped    // 'a;rm -rf x'
    ///     "it's".shellEscaped          // 'it'\''s'
    ///
    /// A tilde must stay outside the quotes to expand - see
    /// `SSHService.escapeRemoteShellPath`, which appends `"~/" + rest.shellEscaped`.
    var shellEscaped: String {
        "'" + self.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
