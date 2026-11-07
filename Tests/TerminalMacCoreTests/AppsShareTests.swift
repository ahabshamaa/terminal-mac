import XCTest
import Foundation
@testable import TerminalMacCore

final class AppsShareTests: XCTestCase {
    var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("terminal-mac-apps-\(UUID().uuidString)")
            .appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home.deletingLastPathComponent())
    }
    func make(_ relative: String) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.standardizedFileURL.resolvingSymlinksInPath()
    }

    func testMissingDefaultFolderIsNotAttached() throws {
        XCTAssertNil(try AppsShare.resolve(environment: [:], home: home))
    }
    func testDefaultFolderIsDeveloperTerminalMacApps() throws {
        let apps = try make("Developer/terminal-mac-apps")
        XCTAssertEqual(try AppsShare.resolve(environment: [:], home: home), apps)
        XCTAssertEqual(AppsShare.name, "apps")
    }
    func testEnvironmentOverride() throws {
        let other = try make("Builds")
        XCTAssertEqual(try AppsShare.resolve(environment: [AppsShare.environmentKey: other.path], home: home), other)
        XCTAssertNil(try AppsShare.resolve(environment: [AppsShare.environmentKey: home.appendingPathComponent("absent").path], home: home))
    }
    func testEmptyOverrideFallsBackToDefault() throws {
        let apps = try make("Developer/terminal-mac-apps")
        XCTAssertEqual(try AppsShare.resolve(environment: [AppsShare.environmentKey: ""], home: home), apps)
    }
    func testRefusesHomeFolder() {
        XCTAssertThrowsError(try AppsShare.resolve(environment: [AppsShare.environmentKey: home.path], home: home))
    }
    func testRefusesFoldersContainingHome() {
        XCTAssertThrowsError(try AppsShare.resolve(environment: [AppsShare.environmentKey: home.deletingLastPathComponent().path], home: home))
        XCTAssertThrowsError(try AppsShare.resolve(environment: [AppsShare.environmentKey: "/"], home: home))
    }
    func testRefusesSymlinkToHome() throws {
        let link = home.deletingLastPathComponent().appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: home)
        XCTAssertThrowsError(try AppsShare.resolve(environment: [AppsShare.environmentKey: link.path], home: home))
    }
    func testRefusesProjectFolder() throws {
        let project = try make("Developer/SomeApp")
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)
        XCTAssertThrowsError(try AppsShare.resolve(environment: [AppsShare.environmentKey: project.path], home: home))
    }
    func testRefusesFile() throws {
        let file = home.appendingPathComponent("file.txt")
        try Data().write(to: file)
        XCTAssertThrowsError(try AppsShare.resolve(environment: [AppsShare.environmentKey: file.path], home: home))
    }
    func testSiblingWithHomePrefixIsAllowed() throws {
        // "/x/home-builds" must not be mistaken for a parent of "/x/home".
        let sibling = home.deletingLastPathComponent().appendingPathComponent("home-builds")
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        XCTAssertEqual(try AppsShare.resolve(environment: [AppsShare.environmentKey: sibling.path], home: home),
                       sibling.standardizedFileURL.resolvingSymlinksInPath())
    }
}
