import AVFoundation
import Foundation

final class M3u8ResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
  private static let cacheScheme = "player-m3u8-cache"

  private let headers: [String: String]
  private let cacheKey: String?
  private let cacheManager: M3u8IosCacheManager
  private let audioUrl: URL?
  private let audioHeaders: [String: String]
  private let externalSubtitles: [[String: Any]]
  private let audioGroupId = "extaudio"
  private let subtitleGroupId = "extsubs"
  var qualityProvider: () -> [String: Any] = { ["isAuto": true] }
  private let queue = DispatchQueue(label: "player_m3u8_resource_loader")
  private let cancellationLock = NSLock()
  private let cancelledRequests =
    NSHashTable<AVAssetResourceLoadingRequest>.weakObjects()
  private var audioPlaylistData: Data?
  private var audioPlaylistInjected = false
  private var subtitlePlaylistDataById: [String: Data] = [:]

  init(
    headers: [String: String],
    cacheKey: String? = nil,
    cacheManager: M3u8IosCacheManager = .shared,
    audioUrl: URL? = nil,
    audioHeaders: [String: String] = [:],
    externalSubtitles: [[String: Any]] = []
  ) {
    self.headers = headers
    self.cacheKey = cacheKey
    self.cacheManager = cacheManager
    self.audioUrl = audioUrl
    self.audioHeaders = audioHeaders
    self.externalSubtitles = externalSubtitles
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
    guard let requestUrl = loadingRequest.request.url else {
      return false
    }

    trackRequest(loadingRequest)

    if requestUrl.host == "audio",
       URLComponents(url: requestUrl, resolvingAgainstBaseURL: false)?
         .queryItems?.first(where: { $0.name == "url" })?.value != nil
    {
      queue.async { [weak self, weak loadingRequest] in
        guard let self, let loadingRequest else { return }
        if let data = self.audioPlaylistData, !self.isCancelled(loadingRequest) {
          self.respond(to: loadingRequest, data: data, isPlaylist: true)
          loadingRequest.finishLoading()
        } else {
          if !self.isCancelled(loadingRequest) {
            loadingRequest.finishLoading(
              with: NSError(domain: "M3u8ResourceLoader", code: -1, userInfo: nil)
            )
          }
        }
        self.clearRequest(loadingRequest)
      }
      return true
    }

    if requestUrl.host == "subtitle",
       let subtitleId = URLComponents(url: requestUrl, resolvingAgainstBaseURL: false)?
         .queryItems?.first(where: { $0.name == "id" })?.value
    {
      queue.async { [weak self, weak loadingRequest] in
        guard let self, let loadingRequest else { return }
        if let data = self.subtitlePlaylistDataById[subtitleId], !self.isCancelled(loadingRequest) {
          self.respond(to: loadingRequest, data: data, isPlaylist: true)
          loadingRequest.finishLoading()
        } else if !self.isCancelled(loadingRequest) {
          loadingRequest.finishLoading(
            with: NSError(domain: "M3u8ResourceLoader", code: -2, userInfo: nil)
          )
        }
        self.clearRequest(loadingRequest)
      }
      return true
    }

    guard let originalUrl = Self.originalUrl(for: requestUrl) else {
      return false
    }
    queue.async { [weak self, weak loadingRequest] in
      guard let self, let loadingRequest else { return }
      do {
        var data = try self.cacheManager.data(
          for: originalUrl,
          headers: self.headers,
          cacheKey: self.cacheKey
        )
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
          if self.isMasterPlaylist(data: data),
             let audioUrl = self.audioUrl,
             self.audioPlaylistData != nil || !self.audioPlaylistInjected
          {
            data = self.injectAudioMedia(data: data, audioUrl: audioUrl)
            self.audioPlaylistInjected = true
          }
          if self.isMasterPlaylist(data: data), !self.externalSubtitles.isEmpty {
            data = self.injectSubtitleMedia(data: data)
          }
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
        var streamInf = rawLine
        if audioUrl != nil {
          streamInf = withAttribute(streamInf, name: "AUDIO", value: audioGroupId)
        }
        if !externalSubtitles.isEmpty {
          streamInf = withAttribute(streamInf, name: "SUBTITLES", value: subtitleGroupId)
        }
        pendingStreamInf = streamInf
        return ""
      }
      if line.hasPrefix("#EXT-X-KEY:") || line.hasPrefix("#EXT-X-MAP:") {
        return Self.rewriteUriAttribute(in: rawLine, playlistUrl: playlistUrl)
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

  private static func rewriteUriAttribute(in line: String, playlistUrl: URL) -> String {
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
    let cachedUrl = cachedUrl(for: originalUrl).absoluteString
    var rewritten = line
    rewritten.replaceSubrange(uriRange, with: cachedUrl)
    return rewritten
  }

  private func withAttribute(_ line: String, name: String, value: String) -> String {
    let attribute = "\(name)=\"\(value)\""
    guard line.contains("\(name)=") else {
      return line.contains(",") ? "\(line),\(attribute)" : "\(line) \(attribute)"
    }
    let pattern = "\(name)=\"[^\"]*\""
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    return regex.stringByReplacingMatches(
      in: line,
      range: range,
      withTemplate: attribute
    )
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

  private func isMasterPlaylist(data: Data) -> Bool {
    guard let text = String(data: data, encoding: .utf8) else { return false }
    return text.contains("#EXT-X-STREAM-INF:")
  }

  private func injectAudioMedia(data: Data, audioUrl: URL) -> Data {
    guard var text = String(data: data, encoding: .utf8) else { return data }
    if audioPlaylistData == nil {
      do {
        let audioData = try cacheManager.data(for: audioUrl, headers: audioHeaders)
        audioPlaylistData = Self.rewriteAudioPlaylist(
          data: audioData,
          playlistUrl: audioUrl
        )
      } catch {
        return data
      }
    }
    text = Self.removingMediaTags(from: text, type: "AUDIO", groupId: audioGroupId)
    let cachedAudioUrl = Self.audioPlaylistUrl(for: audioUrl)
    let audioTag = (
      "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"\(audioGroupId)\",NAME=\"External\","
      + "DEFAULT=YES,AUTOSELECT=YES,URI=\"\(cachedAudioUrl.absoluteString)\"\n"
    )
    if text.contains("#EXT-X-ENDLIST") {
      text = text.replacingOccurrences(of: "#EXT-X-ENDLIST", with: "\(audioTag)#EXT-X-ENDLIST")
    } else {
      text.append("\n\(audioTag)")
    }
    return Data(text.utf8)
  }

  private func injectSubtitleMedia(data: Data) -> Data {
    guard var text = String(data: data, encoding: .utf8) else { return data }
    let tags = externalSubtitles.compactMap { subtitle -> String? in
      guard
        let id = subtitle["id"] as? String,
        !id.isEmpty,
        let urlString = subtitle["url"] as? String,
        let subtitleUrl = URL(string: urlString)
      else {
        return nil
      }
      if subtitlePlaylistDataById[id] == nil {
        let subtitleHeaders = subtitle["headers"] as? [String: String] ?? [:]
        subtitlePlaylistDataById[id] = Self.rewriteSubtitlePlaylist(
          subtitleUrl: subtitleUrl,
          headers: subtitleHeaders,
          cacheManager: cacheManager
        )
      }
      guard subtitlePlaylistDataById[id] != nil else { return nil }
      let label = subtitle["label"] as? String ?? id
      let language = subtitle["language"] as? String
      let defaultValue = subtitle["isDefault"] as? Bool == true ? "YES" : "NO"
      var tag = "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"\(subtitleGroupId)\",NAME=\"\(Self.escapeAttribute(label))\","
      tag += "DEFAULT=\(defaultValue),AUTOSELECT=YES"
      if let language, !language.isEmpty {
        tag += ",LANGUAGE=\"\(Self.escapeAttribute(language))\""
      }
      tag += ",URI=\"\(Self.subtitlePlaylistUrl(for: id).absoluteString)\""
      return tag
    }
    guard !tags.isEmpty else { return data }
    text = Self.removingMediaTags(from: text, type: "SUBTITLES", groupId: subtitleGroupId)
    let subtitleTags = tags.joined(separator: "\n") + "\n"
    if text.contains("#EXT-X-ENDLIST") {
      text = text.replacingOccurrences(of: "#EXT-X-ENDLIST", with: "\(subtitleTags)#EXT-X-ENDLIST")
    } else {
      text.append("\n\(subtitleTags)")
    }
    return Data(text.utf8)
  }

  static func audioPlaylistUrl(for originalUrl: URL) -> URL {
    var components = URLComponents()
    components.scheme = cacheScheme
    components.host = "audio"
    components.queryItems = [
      URLQueryItem(name: "url", value: originalUrl.absoluteString)
    ]
    return components.url!
  }

  static func subtitlePlaylistUrl(for id: String) -> URL {
    var components = URLComponents()
    components.scheme = cacheScheme
    components.host = "subtitle"
    components.queryItems = [
      URLQueryItem(name: "id", value: id)
    ]
    return components.url!
  }

  private static func rewriteAudioPlaylist(data: Data, playlistUrl: URL) -> Data {
    guard let text = String(data: data, encoding: .utf8) else { return data }
    let lines = text.components(separatedBy: .newlines).compactMap { rawLine -> String? in
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { return rawLine }
      if line.hasPrefix("#EXT-X-STREAM-INF:") {
        return nil
      }
      if line.hasPrefix("#") {
        return rawLine
      }
      guard let originalUrl = URL(string: line, relativeTo: playlistUrl)?.absoluteURL else {
        return rawLine
      }
      return M3u8ResourceLoader.cachedUrl(for: originalUrl).absoluteString
    }
    return Data(lines.joined(separator: "\n").utf8)
  }

  private static func rewriteSubtitlePlaylist(
    subtitleUrl: URL,
    headers: [String: String],
    cacheManager: M3u8IosCacheManager
  ) -> Data? {
    guard
      let data = try? cacheManager.data(for: subtitleUrl, headers: headers),
      let text = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    if text.contains("#EXTM3U") {
      let lines = text.components(separatedBy: .newlines).map { rawLine -> String in
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return rawLine }
        if line.hasPrefix("#EXT-X-KEY:") || line.hasPrefix("#EXT-X-MAP:") {
          return rewriteUriAttribute(in: rawLine, playlistUrl: subtitleUrl)
        }
        if line.hasPrefix("#") {
          return rawLine
        }
        guard let originalUrl = URL(string: line, relativeTo: subtitleUrl)?.absoluteURL else {
          return rawLine
        }
        return cachedUrl(for: originalUrl).absoluteString
      }
      return Data(lines.joined(separator: "\n").utf8)
    }
    let cachedSubtitleUrl = cachedUrl(for: subtitleUrl).absoluteString
    let playlistDuration = 86_400
    let playlist = [
      "#EXTM3U",
      "#EXT-X-VERSION:3",
      "#EXT-X-TARGETDURATION:\(playlistDuration)",
      "#EXT-X-MEDIA-SEQUENCE:0",
      "#EXTINF:\(playlistDuration).0,",
      cachedSubtitleUrl,
      "#EXT-X-ENDLIST",
    ].joined(separator: "\n")
    return Data(playlist.utf8)
  }

  private static func removingMediaTags(from text: String, type: String, groupId: String) -> String {
    text.components(separatedBy: .newlines)
      .filter { line in
        !(line.hasPrefix("#EXT-X-MEDIA:") &&
          line.contains("TYPE=\(type)") &&
          line.contains("GROUP-ID=\"\(groupId)\""))
      }
      .joined(separator: "\n")
  }

  private static func escapeAttribute(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}
