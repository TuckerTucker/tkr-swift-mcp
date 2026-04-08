import Foundation

/// Wraps Apple Notes access via AppleScript (osascript).
/// Notes.app has no public framework, so AppleScript is the only stable interface.
actor NotesService {

    // MARK: - Folders

    func listFolders() async throws -> [[String: String]] {
        let script = """
        tell application "Notes"
            set output to ""
            repeat with f in folders
                set output to output & (id of f) & "||" & (name of f) & "\\n"
            end repeat
            return output
        end tell
        """
        let raw = try await runAppleScript(script)
        return raw.split(separator: "\n").compactMap { line -> [String: String]? in
            let parts = line.split(separator: "||", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return ["id": String(parts[0]), "name": String(parts[1])]
        }
    }

    // MARK: - List / Search Notes

    func listNotes(folderName: String?, limit: Int = 50) async throws -> [[String: String]] {
        let target: String
        if let folderName {
            target = "notes of folder \"\(escaped(folderName))\""
        } else {
            target = "notes"
        }

        let script = """
        tell application "Notes"
            set output to ""
            set noteCount to 0
            repeat with n in \(target)
                set output to output & (id of n) & "||" & (name of n) & "||" & (modification date of n as «class isot» as string) & "\\n"
                set noteCount to noteCount + 1
                if noteCount >= \(limit) then exit repeat
            end repeat
            return output
        end tell
        """
        let raw = try await runAppleScript(script)
        return parseNoteList(raw)
    }

    func searchNotes(query: String, limit: Int = 30) async throws -> [[String: String]] {
        // AppleScript Notes doesn't have a search command, so we filter by name and body
        let q = escaped(query).lowercased()
        let script = """
        tell application "Notes"
            set output to ""
            set noteCount to 0
            repeat with n in notes
                set noteName to name of n
                set noteBody to plaintext of n
                if (noteName contains "\(q)") or (noteBody contains "\(q)") then
                    set output to output & (id of n) & "||" & (name of n) & "||" & (modification date of n as «class isot» as string) & "\\n"
                    set noteCount to noteCount + 1
                    if noteCount >= \(limit) then exit repeat
                end if
            end repeat
            return output
        end tell
        """
        let raw = try await runAppleScript(script)
        return parseNoteList(raw)
    }

    // MARK: - Read Note

    func getNote(noteID: String) async throws -> [String: String]? {
        let script = """
        tell application "Notes"
            try
                set n to note id "\(escaped(noteID))"
                set noteFolder to name of container of n
                return (id of n) & "||" & (name of n) & "||" & (plaintext of n) & "||" & noteFolder & "||" & (modification date of n as «class isot» as string) & "||" & (creation date of n as «class isot» as string)
            on error
                return "NOT_FOUND"
            end try
        end tell
        """
        let raw = try await runAppleScript(script)
        if raw.trimmingCharacters(in: .whitespacesAndNewlines) == "NOT_FOUND" { return nil }

        let parts = raw.split(separator: "||", maxSplits: 5).map(String.init)
        guard parts.count >= 4 else { return nil }

        var dict: [String: String] = [
            "id": parts[0],
            "title": parts[1],
            "body": parts[2],
            "folder": parts[3],
        ]
        if parts.count > 4 { dict["modifiedDate"] = parts[4] }
        if parts.count > 5 { dict["createdDate"] = parts[5] }
        return dict
    }

    // MARK: - Create Note

    func createNote(
        title: String,
        body: String,
        folderName: String?
    ) async throws -> [String: String] {
        let htmlBody = "<h1>\(escapedHTML(title))</h1>\(escapedHTML(body).replacingOccurrences(of: "\n", with: "<br>"))"
        let target: String
        if let folderName {
            target = "folder \"\(escaped(folderName))\""
        } else {
            target = "default account"
        }

        let script = """
        tell application "Notes"
            set newNote to make new note at \(target) with properties {body:"\(escaped(htmlBody))"}
            return (id of newNote) & "||" & (name of newNote)
        end tell
        """
        let raw = try await runAppleScript(script)
        let parts = raw.split(separator: "||", maxSplits: 1).map(String.init)
        return [
            "id": parts.first ?? "",
            "title": parts.count > 1 ? parts[1] : title,
        ]
    }

    // MARK: - Update Note

    func updateNote(noteID: String, body: String) async throws -> Bool {
        let htmlBody = escaped(body.replacingOccurrences(of: "\n", with: "<br>"))
        let script = """
        tell application "Notes"
            try
                set n to note id "\(escaped(noteID))"
                set body of n to "\(htmlBody)"
                return "OK"
            on error
                return "NOT_FOUND"
            end try
        end tell
        """
        let raw = try await runAppleScript(script)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    // MARK: - Append to Note

    func appendToNote(noteID: String, text: String) async throws -> Bool {
        let htmlAppend = escaped(text.replacingOccurrences(of: "\n", with: "<br>"))
        let script = """
        tell application "Notes"
            try
                set n to note id "\(escaped(noteID))"
                set body of n to (body of n) & "<br>\(htmlAppend)"
                return "OK"
            on error
                return "NOT_FOUND"
            end try
        end tell
        """
        let raw = try await runAppleScript(script)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    // MARK: - Delete Note

    func deleteNote(noteID: String) async throws -> Bool {
        let script = """
        tell application "Notes"
            try
                delete note id "\(escaped(noteID))"
                return "OK"
            on error
                return "NOT_FOUND"
            end try
        end tell
        """
        let raw = try await runAppleScript(script)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    // MARK: - AppleScript Execution

    private func runAppleScript(_ script: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw NotesError.scriptFailed(errStr)
        }

        return String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Helpers

    private func parseNoteList(_ raw: String) -> [[String: String]] {
        raw.split(separator: "\n").compactMap { line -> [String: String]? in
            let parts = line.split(separator: "||", maxSplits: 2).map(String.init)
            guard parts.count >= 2 else { return nil }
            var dict = ["id": parts[0], "title": parts[1]]
            if parts.count > 2 { dict["modifiedDate"] = parts[2] }
            return dict
        }
    }

    /// Escape for AppleScript string literals.
    private nonisolated func escaped(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private nonisolated func escapedHTML(_ str: String) -> String {
        str.replacingOccurrences(of: "&", with: "&amp;")
           .replacingOccurrences(of: "<", with: "&lt;")
           .replacingOccurrences(of: ">", with: "&gt;")
    }
}

enum NotesError: LocalizedError {
    case scriptFailed(String)
    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg): return "AppleScript error: \(msg)"
        }
    }
}
