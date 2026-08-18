import Foundation
import Darwin

public enum ActivityStatus: Sendable, Equatable {
    case inactive                            // No running sessions
    case idle(sessionCount: Int)             // At prompt waiting for command
    case active(activeCount: Int, total: Int) // Running tools or thinking
    case needsResponse(waitingCount: Int, total: Int) // Blocked on approval / question
    
    public var isLive: Bool {
        switch self {
        case .inactive: return false
        default: return true
        }
    }
    
    public var badgeText: String {
        switch self {
        case .inactive:
            return ""
        case .idle(let count):
            return count > 1 ? "\(count) Idle" : "Idle"
        case .active(let active, let total):
            return total > 1 ? "\(active) of \(total) Active" : "Active"
        case .needsResponse(let waiting, let total):
            return total > 1 ? "Needs response (\(waiting))" : "Needs response"
        }
    }
}

public struct SessionDetector {
    
    public static func detectClaudeStatus() -> ActivityStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sessionsDir = home.appendingPathComponent(".claude/sessions").path
        
        guard FileManager.default.fileExists(atPath: sessionsDir) else {
            return .inactive
        }
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) else {
            return .inactive
        }
        
        var totalAlive = 0
        var activeCount = 0
        var needsResponseCount = 0
        
        for file in files where file.hasSuffix(".json") {
            // Fast-path PID check from filename
            let pidString = (file as NSString).deletingPathExtension
            if let pid = pid_t(pidString) {
                if kill(pid, 0) != 0 {
                    continue
                }
            }
            
            let fullPath = (sessionsDir as NSString).appendingPathComponent(file)
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int else {
                continue
            }
            
            if kill(pid_t(pid), 0) == 0 {
                totalAlive += 1
                let status = (json["status"] as? String)?.lowercased() ?? "idle"
                
                if status == "blocked" || status == "waiting_for_approval" {
                    needsResponseCount += 1
                } else if status == "working" || status == "running" {
                    activeCount += 1
                }
            }
        }
        
        if totalAlive == 0 {
            return .inactive
        }
        if needsResponseCount > 0 {
            return .needsResponse(waitingCount: needsResponseCount, total: totalAlive)
        }
        if activeCount > 0 {
            return .active(activeCount: activeCount, total: totalAlive)
        }
        return .idle(sessionCount: totalAlive)
    }
    
    public static func detectAntigravityStatus() -> ActivityStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let presenceDir = home.appendingPathComponent(".gemini/antigravity-cli/presence").path
        
        guard FileManager.default.fileExists(atPath: presenceDir) else {
            return .inactive
        }
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: presenceDir) else {
            return .inactive
        }
        
        var totalAlive = 0
        var activeCount = 0
        var needsResponseCount = 0
        let now = Date().timeIntervalSince1970
        
        for file in files where file.hasSuffix(".lock") {
            let fullPath = (presenceDir as NSString).appendingPathComponent(file)
            let convId = (file as NSString).deletingPathExtension
            
            let fd = open(fullPath, O_RDWR)
            guard fd >= 0 else { continue }
            
            let lockResult = flock(fd, LOCK_EX | LOCK_NB)
            if lockResult != 0 {
                // Lock actively held by live process
                totalAlive += 1
                close(fd)
                
                let transcriptPath = home.appendingPathComponent(".gemini/antigravity-cli/brain/\(convId)/.system_generated/logs/transcript.jsonl").path
                let walPath = home.appendingPathComponent(".gemini/antigravity-cli/conversations/\(convId).db-wal").path
                
                var isSessionActive = false
                if let walAttrs = try? FileManager.default.attributesOfItem(atPath: walPath),
                   let walMod = walAttrs[.modificationDate] as? Date {
                    if now - walMod.timeIntervalSince1970 < 2.5 {
                        isSessionActive = true
                    }
                }
                
                if let lastLine = readLastLineFast(of: transcriptPath) {
                    if lastLine.contains("ask_question") || lastLine.contains("WAITING_FOR_INPUT") {
                        needsResponseCount += 1
                    } else if isSessionActive || lastLine.contains("\"status\":\"RUNNING\"") || lastLine.contains("\"type\":\"RUN_COMMAND\"") || lastLine.contains("\"type\":\"USER_INPUT\"") || lastLine.contains("\"tool_calls\":[") {
                        activeCount += 1
                    }
                } else if isSessionActive {
                    activeCount += 1
                }
            } else {
                flock(fd, LOCK_UN)
                close(fd)
            }
        }
        
        if totalAlive == 0 {
            return .inactive
        }
        if needsResponseCount > 0 {
            return .needsResponse(waitingCount: needsResponseCount, total: totalAlive)
        }
        if activeCount > 0 {
            return .active(activeCount: activeCount, total: totalAlive)
        }
        return .idle(sessionCount: totalAlive)
    }
    
    private static func readLastLineFast(of path: String) -> String? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        
        let fileSize = lseek(fd, 0, SEEK_END)
        guard fileSize > 0 else { return nil }
        
        let readLen = min(fileSize, 2048)
        guard lseek(fd, fileSize - readLen, SEEK_SET) >= 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: Int(readLen))
        let bytesRead = read(fd, &buffer, Int(readLen))
        guard bytesRead > 0 else { return nil }
        
        let data = Data(buffer[0..<bytesRead])
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return nil }
        let lines = text.split(separator: "\n").map(String.init)
        return lines.last
    }
}
