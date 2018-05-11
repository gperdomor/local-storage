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
import Files

@testable import LocalStorage

// swiftlint:disable identifier_name
let TEST_DIRECTORY = "local-storage-test-directory"
let TEST_DATA = "TEST DATA"
// swiftlint:enable identifier_name

final class LocalAdapterTests: XCTestCase {
    var app: Application!
    var adapter: LocalAdapter!
    var rootDir: Folder!
    var fm = FileManager.default

    override func setUp() {
        super.setUp()
        app = try! Application.testable()
        rootDir = try! Folder.temporary.createSubfolderIfNeeded(withName: TEST_DIRECTORY)

        adapter = try! LocalAdapter(rootDirectory: rootDir.path)

        // create some buckets

        try! rootDir.createSubfolderIfNeeded(withName: "bucket-1")
        try! rootDir.createSubfolderIfNeeded(withName: "bucket-2")
        let b3 = try! rootDir.createSubfolderIfNeeded(withName: "bucket-3")

        try! b3.createFile(named: "file.png", contents: TEST_DATA.convertToData())
        try! b3.createFile(named: "other-file.txt", contents: TEST_DATA.convertToData())
    }

    override func tearDown() {
        super.tearDown()

        try! rootDir.delete()
    }

    // MARK: Bucket tests

    func testCreateBucket() throws {
        var name = "create-1"
        XCTAssertEqual(rootDir.containsSubfolder(named: name), false)
        _ = try adapter.create(bucket: name, metadata: nil, on: app).wait()
        XCTAssertEqual(rootDir.containsSubfolder(named: name), true)

        name = "create-2"
        XCTAssertEqual(rootDir.containsSubfolder(named: name), false)
        _ = try adapter.create(bucket: name, metadata: nil, on: app).wait()
        XCTAssertEqual(rootDir.containsSubfolder(named: name), true)
    }

    // MARK: Delete Bucket

    func testDeleteEmptyBucket() throws {
        let name = "bucket-1"

        XCTAssertTrue(rootDir.containsSubfolder(named: name))
        _ = try adapter.delete(bucket: name, on: app).wait()
        XCTAssertFalse(rootDir.containsSubfolder(named: name))
    }

    func testDeleteNonEmptyBucket() throws {
        let name = "bucket-3"

        XCTAssertTrue(rootDir.containsSubfolder(named: name))
        XCTAssertThrowsError(try adapter.delete(bucket: name, on: app).wait())
    }

    func testDeleteUnknowBucket() throws {
        let name = "non-existence-bucket"

        XCTAssertFalse(rootDir.containsSubfolder(named: name))
        XCTAssertThrowsError(try adapter.delete(bucket: name, on: app).wait())
    }

    // MARK: Get Bucket

    func testGetBucket() throws {
        var name = "bucket-1"
        var bucket = try adapter.get(bucket: name, on: app).wait()

        XCTAssertNotNil(bucket)
        XCTAssertEqual(bucket!.name, name)

        name = "bucket-2"
        bucket = try adapter.get(bucket: name, on: app).wait()

        XCTAssertNotNil(bucket)
        XCTAssertEqual(bucket!.name, name)

        name = "bucket-3"
        bucket = try adapter.get(bucket: name, on: app).wait()

        XCTAssertNotNil(bucket)
        XCTAssertEqual(bucket!.name, name)

        name = "non-existing-bucket"
        XCTAssertThrowsError(try adapter.get(bucket: name, on: app).wait())
    }

    func testListBuckets() throws {
        let buckets = try adapter.list(on: app).wait()

        XCTAssertEqual(buckets.count, 3)

        ["bucket-1", "bucket-2", "bucket-3"].forEach { name in
            XCTAssertTrue(buckets.contains(where: { $0.name == name}))
        }
    }

    // MARK: Objects tests

    func testCopyObject() throws {
        let srcBucket = "bucket-3"
        let srcObject = "file.png"

        let targetBucket = "bucket-2"
        let targetObject = "file-copied.png"

        XCTAssertFalse(try rootDir.subfolder(named: targetBucket).containsFile(named: targetObject))

        let result = try adapter.copy(object: srcObject, from: srcBucket, as: targetObject, to: targetBucket, on: app).wait()

        XCTAssertTrue(try rootDir.subfolder(named: targetBucket).containsFile(named: targetObject))

        XCTAssertEqual(result.name, "file-copied.png")

        let sourceData = try rootDir.subfolder(named: srcBucket).file(named: srcObject).read()
        let targetData = try rootDir.subfolder(named: targetBucket).file(named: targetObject).read()
        XCTAssertEqual(sourceData, targetData)
    }

    func testCreateObject() throws {
        let bucket = "bucket-1"
        var object = "f1"
        var data = Data()

        XCTAssertFalse(try rootDir.subfolder(named: bucket).containsFile(named: object))

        var result = try adapter.create(object: object, in: bucket, with: data, metadata: nil, on: app).wait()

        XCTAssertTrue(try rootDir.subfolder(named: bucket).containsFile(named: object))

        XCTAssertEqual(result.name, object)
        XCTAssertEqual(result.etag, try MD5.hash(data).hexEncodedString())

        object = "f2"
        data = Data(count: 20)

        XCTAssertFalse(try rootDir.subfolder(named: bucket).containsFile(named: object))

        result = try adapter.create(object: object, in: bucket, with: data, metadata: nil, on: app).wait()

        XCTAssertTrue(try rootDir.subfolder(named: bucket).containsFile(named: object))

        XCTAssertEqual(result.name, object)
        XCTAssertEqual(result.etag, try MD5.hash(data).hexEncodedString())
    }

    func testDeleteObject() throws {
        let bucket = "bucket-3"
        let object = "file.png"

        XCTAssertTrue(try rootDir.subfolder(named: bucket).containsFile(named: object))

        try adapter.delete(object: object, in: bucket, on: app).wait()

        XCTAssertFalse(try rootDir.subfolder(named: bucket).containsFile(named: object))
    }

    func testGetObject() throws {
        let data = try adapter.get(object: "file.png", in: "bucket-3", on: app).wait()

        XCTAssertEqual(data, TEST_DATA.convertToData())
    }

    func testListObjects() throws {
        var objects = try adapter.listObjects(in: "bucket-3", prefix: nil, on: app).wait()

        XCTAssertEqual(objects.count, 2)

        ["file.png", "other-file.txt"].forEach { name in
            XCTAssertTrue(objects.contains(where: { $0.name == name}))
        }

        objects = try adapter.listObjects(in: "bucket-3", prefix: "oth", on: app).wait()
        XCTAssertEqual(objects.count, 1)
        XCTAssertEqual(objects[0].name, "other-file.txt")
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
