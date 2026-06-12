import XCTest
import player_m3u8

class RunnerTests: XCTestCase {
  func testHlsCapabilityAcceptsVodMediaPlaylist() {
    let playlist = """
    #EXTM3U
    #EXT-X-TARGETDURATION:6
    #EXTINF:6.0,
    segment0.ts
    #EXTINF:6.0,
    segment1.ts
    #EXT-X-ENDLIST
    """

    XCTAssertNil(M3u8HlsPlaylistCapability.unsupportedReason(in: playlist))
  }

  func testHlsCapabilityRejectsLiveMediaPlaylist() {
    let playlist = """
    #EXTM3U
    #EXT-X-TARGETDURATION:6
    #EXTINF:6.0,
    segment0.ts
    """

    XCTAssertEqual(
      M3u8HlsPlaylistCapability.unsupportedReason(in: playlist),
      "live_playlist_not_precacheable"
    )
  }

  func testHlsCapabilityRejectsEventPlaylist() {
    let playlist = """
    #EXTM3U
    #EXT-X-PLAYLIST-TYPE:EVENT
    #EXTINF:6.0,
    segment0.ts
    #EXT-X-ENDLIST
    """

    XCTAssertEqual(
      M3u8HlsPlaylistCapability.unsupportedReason(in: playlist),
      "event_playlist_not_precacheable"
    )
  }

  func testHlsCapabilityRejectsByteRangePlaylist() {
    let playlist = """
    #EXTM3U
    #EXT-X-TARGETDURATION:6
    #EXTINF:6.0,
    #EXT-X-BYTERANGE:75232@0
    file.ts
    #EXT-X-ENDLIST
    """

    XCTAssertEqual(
      M3u8HlsPlaylistCapability.unsupportedReason(in: playlist),
      "byterange_not_supported"
    )
  }

  func testHlsCapabilityRejectsUnsupportedEncryption() {
    let playlist = """
    #EXTM3U
    #EXT-X-TARGETDURATION:6
    #EXT-X-KEY:METHOD=SAMPLE-AES,KEYFORMAT="com.apple.streamingkeydelivery"
    #EXTINF:6.0,
    segment0.ts
    #EXT-X-ENDLIST
    """

    XCTAssertEqual(
      M3u8HlsPlaylistCapability.unsupportedReason(in: playlist),
      "encrypted_playlist_not_supported"
    )
  }

  func testHlsParserParsesMasterPlaylistVariants() throws {
    let playlist = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
    mid/index.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=4800000,RESOLUTION=1920x1080,FRAME-RATE=29.970
    high/index.m3u8
    """

    let variants = M3u8HlsPlaylistParser.parseVariants(
      in: playlist,
      baseUrl: try XCTUnwrap(URL(string: "https://cdn.example.com/video/master.m3u8?token=secret"))
    )

    XCTAssertEqual(variants.count, 2)
    XCTAssertEqual(variants[0].height, 1080)
    XCTAssertEqual(variants[0].effectiveBitrate, 4_800_000)
    XCTAssertEqual(variants[0].frameRate, 29.970)
    XCTAssertEqual(variants[0].uri.absoluteString, "https://cdn.example.com/video/high/index.m3u8")
    XCTAssertEqual(variants[1].height, 720)
    XCTAssertEqual(variants[1].codecs, "avc1.64001f,mp4a.40.2")
  }

  func testHlsParserHandlesQuotedCommasInAttributes() {
    let attributes = M3u8HlsPlaylistParser.parseAttributes(
      #"BANDWIDTH=2400000,CODECS="avc1.64001f,mp4a.40.2",RESOLUTION=1280x720"#
    )

    XCTAssertEqual(attributes["BANDWIDTH"], "2400000")
    XCTAssertEqual(attributes["CODECS"], "avc1.64001f,mp4a.40.2")
    XCTAssertEqual(attributes["RESOLUTION"], "1280x720")
  }

  func testHlsParserUsesAverageBandwidthFallback() throws {
    let playlist = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=3000000,AVERAGE-BANDWIDTH=1800000,RESOLUTION=1280x720
    720p.m3u8
    """

    let variants = M3u8HlsPlaylistParser.parseVariants(
      in: playlist,
      baseUrl: try XCTUnwrap(URL(string: "https://cdn.example.com/video/master.m3u8"))
    )

    XCTAssertEqual(variants.single?.bandwidth, 3_000_000)
    XCTAssertEqual(variants.single?.averageBandwidth, 1_800_000)
    XCTAssertEqual(variants.single?.effectiveBitrate, 1_800_000)
  }

  func testHlsParserDoesNotCollapseSameHeightDifferentBitrateVariants() throws {
    let playlist = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720
    720-low.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
    720-high.m3u8
    """

    let variants = M3u8HlsPlaylistParser.parseVariants(
      in: playlist,
      baseUrl: try XCTUnwrap(URL(string: "https://cdn.example.com/video/master.m3u8"))
    )

    XCTAssertEqual(variants.count, 2)
    XCTAssertEqual(variants.map(\.effectiveBitrate), [2_800_000, 1_500_000])
  }

  func testHlsParserReturnsNoVariantsForMediaPlaylist() throws {
    let playlist = """
    #EXTM3U
    #EXT-X-TARGETDURATION:6
    #EXTINF:6.0,
    segment0.ts
    #EXT-X-ENDLIST
    """

    let variants = M3u8HlsPlaylistParser.parseVariants(
      in: playlist,
      baseUrl: try XCTUnwrap(URL(string: "https://cdn.example.com/video/index.m3u8"))
    )

    XCTAssertTrue(variants.isEmpty)
  }

  func testHlsParserExposesSafeVariantSourceIdsOnly() throws {
    let playlist = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720
    https://cdn.example.com/video/720p.m3u8?token=secret
    """

    let variant = try XCTUnwrap(
      M3u8HlsPlaylistParser.parseVariants(
        in: playlist,
        baseUrl: try XCTUnwrap(URL(string: "https://cdn.example.com/video/master.m3u8"))
      ).single
    )
    let sourceId = M3u8HlsPlaylistParser.sourceId(for: variant.uri)

    XCTAssertFalse(sourceId.contains("token"))
    XCTAssertFalse(sourceId.contains("https://"))
  }
}

private extension Array {
  var single: Element? {
    count == 1 ? self[0] : nil
  }
}
