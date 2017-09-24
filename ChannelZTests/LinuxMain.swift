import XCTest

@testable import ChannelZTests

#if !os(macOS)
XCTMain([
  ChannelTestCase.allTests,
])
#endif
