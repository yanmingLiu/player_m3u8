import Foundation

public enum M3u8HlsPlaylistParser {
  public struct Variant: Equatable {
    public let uri: URL
    public let width: Int
    public let height: Int
    public let bandwidth: Int
    public let averageBandwidth: Int
    public let codecs: String?
    public let frameRate: Double?

    public var effectiveBitrate: Int {
      if averageBandwidth > 0 {
        return averageBandwidth
      }
      return bandwidth
    }
  }

  public static func parseVariants(in text: String, baseUrl: URL) -> [Variant] {
    guard text.uppercased().contains("#EXTM3U") else { return [] }
    var variants: [Variant] = []
    var pendingAttributes: [String: String]?

    for rawLine in text.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }
      let uppercased = line.uppercased()

      if uppercased.hasPrefix("#EXT-X-STREAM-INF:") {
        pendingAttributes = parseAttributes(
          String(line.dropFirst("#EXT-X-STREAM-INF:".count))
        )
        continue
      }
      if uppercased.hasPrefix("#") {
        continue
      }
      guard let attributes = pendingAttributes else { continue }
      pendingAttributes = nil
      guard let uri = URL(string: line, relativeTo: baseUrl)?.absoluteURL else {
        continue
      }

      let resolution = attributes["RESOLUTION"] ?? ""
      let parts = resolution.split(separator: "x", maxSplits: 1)
      let width = Int(parts.first ?? "") ?? 0
      let height = Int(parts.dropFirst().first ?? "") ?? 0
      let bandwidth = Int(attributes["BANDWIDTH"] ?? "") ?? 0
      let averageBandwidth = Int(attributes["AVERAGE-BANDWIDTH"] ?? "") ?? 0
      variants.append(
        Variant(
          uri: uri,
          width: max(width, 0),
          height: max(height, 0),
          bandwidth: max(bandwidth, 0),
          averageBandwidth: max(averageBandwidth, 0),
          codecs: attributes["CODECS"],
          frameRate: Double(attributes["FRAME-RATE"] ?? "")
        )
      )
    }

    var seen = Set<String>()
    return variants
      .filter { variant in
        let key = [
          String(variant.height),
          String(variant.effectiveBitrate),
          sourceId(for: variant.uri),
        ].joined(separator: "|")
        guard !seen.contains(key) else { return false }
        seen.insert(key)
        return true
      }
      .sorted { lhs, rhs in
        if lhs.height != rhs.height {
          return lhs.height > rhs.height
        }
        if lhs.effectiveBitrate != rhs.effectiveBitrate {
          return lhs.effectiveBitrate > rhs.effectiveBitrate
        }
        return sourceId(for: lhs.uri) < sourceId(for: rhs.uri)
      }
  }

  public static func parseAttributes(_ text: String) -> [String: String] {
    var attributes: [String: String] = [:]
    var key = ""
    var value = ""
    var readingKey = true
    var isQuoted = false

    func commit() {
      let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
      let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !normalizedKey.isEmpty {
        attributes[normalizedKey] = normalizedValue.trimmingCharacters(
          in: CharacterSet(charactersIn: "\"")
        )
      }
      key = ""
      value = ""
      readingKey = true
      isQuoted = false
    }

    for character in text {
      if readingKey {
        if character == "=" {
          readingKey = false
        } else if character == "," {
          commit()
        } else {
          key.append(character)
        }
        continue
      }

      if character == "\"" {
        isQuoted.toggle()
        value.append(character)
      } else if character == "," && !isQuoted {
        commit()
      } else {
        value.append(character)
      }
    }
    commit()
    return attributes
  }

  public static func sourceId(for url: URL) -> String {
    String(abs(url.absoluteString.hashValue), radix: 16)
  }
}
