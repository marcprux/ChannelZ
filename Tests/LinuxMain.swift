import XCTest
@testable import ChannelZTests

XCTMain([
    testCase(ChannelTests.allTests),
    testCase(DispatchTests.allTests),
])
