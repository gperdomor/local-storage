//
//  LocalAdapterTests.swift
//  LocalStorage
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import XCTest
import Crypto
import Vapor

@testable import LocalStorage

// swiftlint:disable identifier_name
let TEST_DIRECTORY = "local-storage-test-directory"
let TEST_DATA = "TEST DATA"
// swiftlint:enable identifier_name

final class LocalAdapterTests: XCTestCase {
    var app: Application!
    var adapter: LocalAdapter!
    var rootDir: URL!
    var fm = FileManager.default

    override func setUp() {
        super.setUp()
        app = try! Application.testable()
        rootDir = fm.temporaryDirectory.appendingPathComponent(TEST_DIRECTORY)

        adapter = try! LocalAdapter(rootDirectory: rootDir, create: true)

        // create some buckets

        let path = rootDir.path

        try! fm.createDirectory(atPath: "\(path)/bucket-1", withIntermediateDirectories: true)
        try! fm.createDirectory(atPath: "\(path)/bucket-2", withIntermediateDirectories: true)
        try! fm.createDirectory(atPath: "\(path)/bucket-3", withIntermediateDirectories: true)

        fm.createFile(atPath: "\(path)/bucket-3/file.png", contents: TEST_DATA.convertToData())
        fm.createFile(atPath: "\(path)/bucket-3/other-file.txt", contents: TEST_DATA.convertToData())
    }

    override func tearDown() {
        super.tearDown()

        try! fm.removeItem(at: rootDir)
    }

    func testComputePath() throws {
        XCTAssertEqual(adapter.compute(bucket: "bucket-1", object: nil), "\(rootDir.path)/bucket-1")
        XCTAssertEqual(adapter.compute(bucket: "bucket-2", object: ""), "\(rootDir.path)/bucket-2")
        XCTAssertEqual(adapter.compute(bucket: "bucket-3", object: "object1.png"), "\(rootDir.path)/bucket-3/object1.png")
    }

    // MARK: Bucket tests

    func testCreateBucket() throws {
        var path = rootDir.appendingPathComponent("create-1").path

        XCTAssertEqual(isDirectory(at: path), false)
        _ = try adapter.create(bucket: "create-1", on: app)
        XCTAssertEqual(isDirectory(at: path), true)

        path = rootDir.appendingPathComponent("create-2").path

        XCTAssertEqual(isDirectory(at: path), false)
        _ = try adapter.create(bucket: "create-2", on: app)
        XCTAssertEqual(isDirectory(at: path), true)
    }

    // MARK: Delete Bucket

    func testDeleteEmptyBucket() throws {
        let path = rootDir.appendingPathComponent("bucket-1").path

        XCTAssertTrue(isDirectory(at: path))
        _ = try adapter.delete(bucket: "bucket-1", on: app)
        XCTAssertFalse(isDirectory(at: path))
    }

    func testDeleteNonEmptyBucket() throws {
        let path = rootDir.appendingPathComponent("bucket-3").path

        XCTAssertTrue(isDirectory(at: path))
        XCTAssertThrowsError(try adapter.delete(bucket: "bucket-3", on: app))
        XCTAssertTrue(isDirectory(at: path))
    }

    func testDeleteUnknowBucket() throws {
        let path = rootDir.appendingPathComponent("non-existence-bucket").path

        XCTAssertFalse(isDirectory(at: path))
        XCTAssertThrowsError(try adapter.delete(bucket: "non-existence-bucket", on: app))
    }

    // MARK: Get Bucket

    func testGetBucket() throws {
        var bucket = try adapter.get(bucket: "bucket-1")

        XCTAssertNotNil(bucket)
        XCTAssertTrue(bucket!.name == "bucket-1")

        bucket = try adapter.get(bucket: "bucket-2")

        XCTAssertNotNil(bucket)
        XCTAssertTrue(bucket!.name == "bucket-2")

        bucket = try adapter.get(bucket: "non-existing-bucket")

        XCTAssertNil(bucket)

        let future = try adapter.get(bucket: "bucket-3", on: app)

        XCTAssertNotNil(try future.wait())
        XCTAssertEqual(try future.wait()!.name, "bucket-3")
    }

    func testListBuckets() throws {
        let plain = try adapter.list()

        XCTAssertEqual(plain.count, 3)

        ["bucket-1", "bucket-2", "bucket-3"].forEach { name in
            XCTAssertTrue(plain.contains(where: { $0.name == name}))
        }

        let future = try adapter.list(on: app)

        try ["bucket-1", "bucket-2", "bucket-3"].forEach { name in
            XCTAssertTrue(try future.wait().contains(where: { $0.name == name}))
        }
    }

    // MARK: Objects tests

    func testCopyObject() throws {
        let targetPath = "\(rootDir.path)/bucket-2/file-copied.png"

        XCTAssertFalse(fm.fileExists(atPath: targetPath))
        let future = try adapter.copy(object: "file.png", from: "bucket-3", as: "file-copied.png", to: "bucket-2", on: app)
        XCTAssertTrue(fm.fileExists(atPath: targetPath))

        XCTAssertEqual(try future.wait().name, "file-copied.png")

        let sourceData = fm.contents(atPath: "\(rootDir.path)/bucket-3/file.png")
        let targetData = fm.contents(atPath: targetPath)

        XCTAssertEqual(sourceData, targetData)
    }

    func testCreateObject() throws {
        XCTAssertFalse(fm.fileExists(atPath: "\(rootDir.path)/bucket-1/f1"))

        var data = Data()
        var object = try adapter.create(object: "f1", in: "bucket-1", with: data, on: app).wait()

        XCTAssertTrue(fm.fileExists(atPath: "\(rootDir.path)/bucket-1/f1"))
        XCTAssertEqual(object.name, "f1")
        XCTAssertEqual(object.etag, try MD5.hash(data).hexEncodedString())

        XCTAssertFalse(fm.fileExists(atPath: "\(rootDir.path)/bucket-1/f2"))

        data = Data(count: 20)
        object = try adapter.create(object: "f2", in: "bucket-1", with: data, on: app).wait()

        XCTAssertTrue(fm.fileExists(atPath: "\(rootDir.path)/bucket-1/f2"))
        XCTAssertEqual(object.name, "f2")
        XCTAssertEqual(object.etag, try MD5.hash(data).hexEncodedString())
    }

    func testDeleteObject() throws {
        XCTAssertTrue(fm.fileExists(atPath: "\(rootDir.path)/bucket-3/file.png"))

        try adapter.delete(object: "file.png", in: "bucket-3", on: app).wait()

        XCTAssertFalse(fm.fileExists(atPath: "\(rootDir.path)/bucket-3/file.png"))
    }

    func testGetObject() throws {
        let data = try adapter.get(object: "file.png", in: "bucket-3", on: app).wait()

        XCTAssertEqual(data, TEST_DATA.convertToData())
    }

    func testListObjects() throws {
        var list = try adapter.listObjects(in: "bucket-3", prefix: nil)

        XCTAssertEqual(list.count, 2)

        ["file.png", "other-file.txt"].forEach { name in
            XCTAssertTrue(list.contains(where: { $0.name == name}))
        }

        list = try adapter.listObjects(in: "bucket-3", prefix: "oth")
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].name, "other-file.txt")
    }

    func testLinuxTestSuiteIncludesAllTests() throws {
       #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
       let thisClass = type(of: self)
       let linuxCount = thisClass.allTests.count
       let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)

       XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
       #endif
    }

    static var allTests = [
        ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
        ("testComputePath", testComputePath),
        ("testCreateBucket", testCreateBucket),
        ("testDeleteEmptyBucket", testDeleteEmptyBucket),
        ("testDeleteNonEmptyBucket", testDeleteNonEmptyBucket),
        ("testDeleteUnknowBucket", testDeleteUnknowBucket),
        ("testGetBucket", testGetBucket),
        ("testListBuckets", testListBuckets),
        ("testCopyObject", testCopyObject),
        ("testCreateObject", testCreateObject),
        ("testDeleteObject", testDeleteObject),
        ("testGetObject", testGetObject),
        ("testListObjects", testListObjects)
        ]
}

/// Verify if the path is a directory.
///
/// - Parameter path: the path.
/// - Returns: `true` if the path exists and is a directory, `false` in other cases`.
internal func isDirectory(at path: String) -> Bool {
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}
