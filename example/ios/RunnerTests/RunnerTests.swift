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
}
