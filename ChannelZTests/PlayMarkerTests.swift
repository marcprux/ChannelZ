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
    func testPlaydown() throws {
        // TODO: move this to part of the build process
        let file = __FILE__ as NSString
        let root = NSURL(fileURLWithPath: (file.stringByDeletingLastPathComponent as NSString).stringByDeletingLastPathComponent)
        for srcdst in [
            ("README.md", "Playgrounds/Introduction.playground"),
            ] {
            try PlayMarker.generatePlaydown(root.URLByAppendingPathComponent(srcdst.0), playgroundFolder: root.URLByAppendingPathComponent(srcdst.1))
        }
    }
}

#endif
