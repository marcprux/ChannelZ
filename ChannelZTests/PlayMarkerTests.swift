//
//  PlaydownGeneratorTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

#if os(OSX)

import Foundation
import XCTest

class PlayMarkerTests : XCTestCase {
    /// Generate the playground from the README
    func testPlaydown() {
        // TODO: move this to part of the build process
        if let root = NSURL(fileURLWithPath: __FILE__.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent) {
            for srcdst in [
                ("README.md", "Playgrounds/Introduction.playground"),
                ] {
                var error: NSError?
                PlayMarker.generatePlaydown(root.URLByAppendingPathComponent(srcdst.0), playgroundFolder: root.URLByAppendingPathComponent(srcdst.1), error: &error)
                XCTAssertNil(error)
            }
        }
    }
}

#endif
