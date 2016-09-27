////
////  PlaydownGeneratorTests.swift
////  ChannelZ
////
////  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
////  License: MIT (or whatever)
////
//
//#if os(OSX)
//
//import Foundation
//import XCTest
//
//class PlayMarkerTests : ChannelTestCase {
//    /// Generate the playground from the README
//    func testPlaydown() throws {
//        // TODO: move this to part of the build process
//        let file = #file as NSString
//        let root = URL(fileURLWithPath: (file.deletingLastPathComponent as NSString).deletingLastPathComponent)
//        for srcdst in [
//            ("README.md", "Playgrounds/Introduction.playground"),
//            ] {
//            try PlayMarker.generatePlaydown(root.appendingPathComponent(srcdst.0), playgroundFolder: root.appendingPathComponent(srcdst.1))
//        }
//    }
//}
//
//#endif
