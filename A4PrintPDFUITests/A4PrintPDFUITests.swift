//
//  A4PrintPDFUITests.swift
//  A4PrintPDFUITests
//
//  Created by ゆー on 2026/02/08.
//

import XCTest

final class A4PrintPDFUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - スクリーンショット撮影

    @MainActor
    func testScreenshot01_HomeScreen() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // ホーム画面（写真未選択の初期状態）
        snapshot("01_HomeScreen")
    }

    @MainActor
    func testScreenshot02_PhotosSelected() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // 写真選択ボタンをタップ
        let photoPicker = app.buttons["写真を選択（最大4枚）"]
        if photoPicker.waitForExistence(timeout: 5) {
            photoPicker.tap()

            // PhotosPicker が表示されたら写真を選択
            // 注: シミュレータに事前に写真を追加しておく必要があります
            sleep(2)

            let images = app.images
            for i in 0..<min(4, images.count) {
                images.element(boundBy: i).tap()
            }

            let addButton = app.buttons["Add"]
            if addButton.waitForExistence(timeout: 3) {
                addButton.tap()
            }

            sleep(1)
        }

        snapshot("02_PhotosSelected")
    }

    @MainActor
    func testScreenshot03_PDFPreview() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        let photoPicker = app.buttons["写真を選択（最大4枚）"]
        if photoPicker.waitForExistence(timeout: 5) {
            photoPicker.tap()
            sleep(2)

            let images = app.images
            for i in 0..<min(4, images.count) {
                images.element(boundBy: i).tap()
            }

            let addButton = app.buttons["Add"]
            if addButton.waitForExistence(timeout: 3) {
                addButton.tap()
            }
            sleep(1)
        }

        // PDF生成ボタンをタップ
        let generateButton = app.buttons["A4データを作成"]
        if generateButton.waitForExistence(timeout: 5) {
            generateButton.tap()
            sleep(3)
        }

        snapshot("03_PDFPreview")
    }
}
