import AVFoundation
import Foundation

final class M3u8ResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
  private static let cacheScheme = "player-m3u8-cache"

  private let headers: [String: String]
  private let cacheManager: M3u8IosCacheManager
  var qualityProvider: () -> [String: Any] = { ["isAuto": true] }
  private let queue = DispatchQueue(label: "player_m3u8_resource_loader")
  private let cancellationLock = NSLock()
  private let cancelledRequests =
    NSHashTable<AVAssetResourceLoadingRequest>.weakObjects()

  init(
    headers: [String: String],
    cacheManager: M3u8IosCacheManager = .shared
  ) {
    self.headers = headers
    self.cacheManager = cacheManager
    super.init()
  }

  static func cachedUrl(for originalUrl: URL) -> URL {
    var components = URLComponents()
    components.scheme = cacheScheme
    components.host = "resource"
    components.queryItems = [
      URLQueryItem(name: "url", value: originalUrl.absoluteString)
    ]
    return components.url!
  }

  static func originalUrl(for cachedUrl: URL) -> URL? {
    guard cachedUrl.scheme == cacheScheme else { return nil }
    let components = URLComponents(url: cachedUrl, resolvingAgainstBaseURL: false)
    let value = components?.queryItems?.first(where: { $0.name == "url" })?.value
    return value.flatMap(URL.init(string:))
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
  ) -> Bool {
    guard
      let requestUrl = loadingRequest.request.url,
      let originalUrl = Self.originalUrl(for: requestUrl)
    else {
      return false
    }

    trackRequest(loadingRequest)
    queue.async { [weak self, weak loadingRequest] in
      guard let self, let loadingRequest else { return }
      do {
        var data = try self.cacheManager.data(for: originalUrl, headers: self.headers)
        guard !self.isCancelled(loadingRequest) else {
          self.clearRequest(loadingRequest)
          return
        }
        let isPlaylist = self.isPlaylist(url: originalUrl, data: data)
        if isPlaylist {
          data = self.rewritePlaylist(
            data: data,
            playlistUrl: originalUrl,
            selectedQuality: self.qualityProvider()
          )
        }
        self.respond(to: loadingRequest, data: data, isPlaylist: isPlaylist)
        loadingRequest.finishLoading()
        self.clearRequest(loadingRequest)
      } catch {
        if !self.isCancelled(loadingRequest) {
          loadingRequest.finishLoading(with: error)
        }
        self.clearRequest(loadingRequest)
      }
    }
    return true
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    didCancel loadingRequest: AVAssetResourceLoadingRequest
  ) {
    markCancelled(loadingRequest)
  }

  private func respond(
    to loadingRequest: AVAssetResourceLoadingRequest,
    data: Data,
    isPlaylist: Bool
  ) {
    if let contentInformationRequest = loadingRequest.contentInformationRequest {
      contentInformationRequest.contentType = isPlaylist
        ? "public.m3u-playlist"
        : "public.data"
      contentInformationRequest.contentLength = Int64(data.count)
      contentInformationRequest.isByteRangeAccessSupported = true
    }

    guard let dataRequest = loadingRequest.dataRequest else { return }
    let requestedOffset = Int(max(dataRequest.currentOffset, dataRequest.requestedOffset))
    guard requestedOffset < data.count else {
      dataRequest.respond(with: Data())
      return
    }
    let requestedLength = dataRequest.requestedLength
    let availableLength = data.count - requestedOffset
    let responseLength = max(0, min(requestedLength, availableLength))
    let responseData = data.subdata(
      in: requestedOffset..<(requestedOffset + responseLength)
    )
    dataRequest.respond(with: responseData)
  }

  private func isPlaylist(url: URL, data: Data) -> Bool {
    if url.pathExtension.lowercased() == "m3u8" {
      return true
    }
    guard let prefix = String(data: data.prefix(32), encoding: .utf8) else {
      return false
    }
    return prefix.contains("#EXTM3U")
  }

  private func rewritePlaylist(
    data: Data,
    playlistUrl: URL,
    selectedQuality: [String: Any]
  ) -> Data {
    guard let text = String(data: data, encoding: .utf8) else { return data }
    let selectedHeight = selectedQuality["height"] as? Int ?? 0
    let selectedBitrate = selectedQuality["bitrate"] as? Int ?? 0
    let shouldFilterVariant = !(selectedQuality["isAuto"] as? Bool ?? false) &&
      (selectedHeight > 0 || selectedBitrate > 0)
    var pendingStreamInf: String?
    let lines = text.components(separatedBy: .newlines).map { rawLine -> String in
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { return rawLine }
      if line.hasPrefix("#EXT-X-STREAM-INF:") {
        pendingStreamInf = rawLine
        return ""
      }
      if line.hasPrefix("#EXT-X-KEY:") || line.hasPrefix("#EXT-X-MAP:") {
        return rewriteUriAttribute(in: rawLine, playlistUrl: playlistUrl)
      }
      if line.hasPrefix("#") {
        return rawLine
      }
      guard let originalUrl = URL(string: line, relativeTo: playlistUrl)?.absoluteURL else {
        return rawLine
      }
      let rewrittenUrl = Self.cachedUrl(for: originalUrl).absoluteString
      guard let streamInf = pendingStreamInf else {
        return rewrittenUrl
      }
      pendingStreamInf = nil
      if shouldFilterVariant &&
        !streamInfMatches(streamInf, height: selectedHeight, bitrate: selectedBitrate)
      {
        return ""
      }
      return "\(streamInf)\n\(rewrittenUrl)"
    }
    return Data(lines.filter { !$0.isEmpty }.joined(separator: "\n").utf8)
  }

  private func streamInfMatches(_ line: String, height: Int, bitrate: Int) -> Bool {
    if height > 0,
      let resolution = parseAttribute(line, name: "RESOLUTION"),
      resolution.hasSuffix("x\(height)")
    {
      return true
    }
    if bitrate > 0,
      let bandwidth = Int(parseAttribute(line, name: "BANDWIDTH") ?? ""),
      bandwidth <= bitrate
    {
      return true
    }
    return false
  }

  private func parseAttribute(_ line: String, name: String) -> String? {
    let pattern = "\(name)=([^,]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard
      let match = regex.firstMatch(in: line, range: range),
      let valueRange = Range(match.range(at: 1), in: line)
    else {
      return nil
    }
    return String(line[valueRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
  }

  private func rewriteUriAttribute(in line: String, playlistUrl: URL) -> String {
    let pattern = #"URI="([^"]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard
      let match = regex.firstMatch(in: line, range: range),
      let uriRange = Range(match.range(at: 1), in: line)
    else {
      return line
    }
    let value = String(line[uriRange])
    guard let originalUrl = URL(string: value, relativeTo: playlistUrl)?.absoluteURL else {
      return line
    }
    let cachedUrl = Self.cachedUrl(for: originalUrl).absoluteString
    var rewritten = line
    rewritten.replaceSubrange(uriRange, with: cachedUrl)
    return rewritten
  }

  private func trackRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
    cancellationLock.lock()
    cancelledRequests.remove(loadingRequest)
    cancellationLock.unlock()
  }

  private func markCancelled(_ loadingRequest: AVAssetResourceLoadingRequest) {
    cancellationLock.lock()
    cancelledRequests.add(loadingRequest)
    cancellationLock.unlock()
  }

  private func isCancelled(_ loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
    cancellationLock.lock()
    defer { cancellationLock.unlock() }
    return cancelledRequests.contains(loadingRequest)
  }

  private func clearRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
    cancellationLock.lock()
    cancelledRequests.remove(loadingRequest)
    cancellationLock.unlock()
  }
}
