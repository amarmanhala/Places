//
//  OCRLogger.swift
//  places
//
//  Created by Claude Code
//  OCR Testing & Analysis Database
//

import Foundation
import SQLite3
import UIKit

// MARK: - DEBUG FLAG
// Set to false when ready for production to disable all OCR testing features
let DEBUG_OCR = true

class OCRLogger {
    static let shared = OCRLogger()
    private var db: OpaquePointer?
    private var imagesDirectory: URL?

    private init() {
        guard DEBUG_OCR else { return }
        setupImagesDirectory()
        openDatabase()
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func setupImagesDirectory() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imagesDirectory = documentsPath.appendingPathComponent("ocr_images", isDirectory: true)

        if let path = imagesDirectory?.path, !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(at: imagesDirectory!, withIntermediateDirectories: true)
            print("✅ OCR images directory created at: \(path)")
        }
    }

    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("ocr_analysis.sqlite")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ Error opening database")
            return
        }

        print("✅ OCR Analysis database opened at: \(fileURL.path)")
    }

    private func createTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS ocr_attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,

            -- Image metadata
            image_hash TEXT,
            image_path TEXT,
            brightness_avg REAL,
            time_of_day TEXT,

            -- What we selected
            selected_text TEXT,
            selected_score REAL,
            selected_confidence REAL,
            selected_method TEXT,
            selected_position_x REAL,
            selected_position_y REAL,
            selected_size REAL,

            -- User correction
            corrected_text TEXT,
            was_correct INTEGER DEFAULT NULL,
            correction_timestamp DATETIME,

            -- All candidates (JSON)
            all_candidates TEXT,
            all_methods_summary TEXT,

            -- Storefront characteristics
            has_bright_text INTEGER,
            dominant_color TEXT,
            text_position TEXT,

            -- Performance
            processing_time_ms INTEGER,
            num_candidates INTEGER,
            num_methods_detected INTEGER,

            -- Raw data for debugging
            console_log TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_was_correct ON ocr_attempts(was_correct);
        CREATE INDEX IF NOT EXISTS idx_selected_method ON ocr_attempts(selected_method);
        CREATE INDEX IF NOT EXISTS idx_timestamp ON ocr_attempts(timestamp);
        CREATE INDEX IF NOT EXISTS idx_selected_text ON ocr_attempts(selected_text);
        """

        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableSQL, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("✅ OCR attempts table created/verified")
            }
        } else {
            print("❌ CREATE TABLE statement could not be prepared")
        }
        sqlite3_finalize(createTableStatement)
    }

    // MARK: - Logging Functions

    struct OCRAttempt {
        let imageHash: String
        let imagePath: String?
        let brightnessAvg: Float
        let timeOfDay: String
        let selectedText: String?
        let selectedScore: Float?
        let selectedConfidence: Float?
        let selectedMethod: String?
        let selectedPositionX: Float?
        let selectedPositionY: Float?
        let selectedSize: Float?
        let allCandidates: String  // JSON
        let allMethodsSummary: String  // JSON
        let hasBrightText: Bool
        let dominantColor: String?
        let textPosition: String
        let processingTimeMs: Int
        let numCandidates: Int
        let numMethodsDetected: Int
        let consoleLog: String
    }

    // Save image to disk and return path
    func saveImage(_ image: UIImage, hash: String) -> String? {
        guard DEBUG_OCR, let imagesDirectory = imagesDirectory else { return nil }

        // Resize to max width 800px to save space
        let resizedImage = resizeImage(image, maxWidth: 800)

        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        let filename = "\(hash).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            print("✅ Image saved: \(filename) (\(imageData.count / 1024)KB)")
            return fileURL.path
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }

    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let scale = maxWidth / image.size.width
        if scale >= 1 { return image }

        let newHeight = image.size.height * scale
        let newSize = CGSize(width: maxWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    func logOCRAttempt(_ attempt: OCRAttempt) {
        guard DEBUG_OCR else { return }

        let insertSQL = """
        INSERT INTO ocr_attempts (
            image_hash, image_path, brightness_avg, time_of_day,
            selected_text, selected_score, selected_confidence, selected_method,
            selected_position_x, selected_position_y, selected_size,
            all_candidates, all_methods_summary,
            has_bright_text, dominant_color, text_position,
            processing_time_ms, num_candidates, num_methods_detected,
            console_log
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var insertStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
            // Bind all parameters
            sqlite3_bind_text(insertStatement, 1, (attempt.imageHash as NSString).utf8String, -1, nil)

            if let path = attempt.imagePath {
                sqlite3_bind_text(insertStatement, 2, (path as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStatement, 2)
            }

            sqlite3_bind_double(insertStatement, 3, Double(attempt.brightnessAvg))
            sqlite3_bind_text(insertStatement, 4, (attempt.timeOfDay as NSString).utf8String, -1, nil)

            if let text = attempt.selectedText {
                sqlite3_bind_text(insertStatement, 5, (text as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStatement, 5)
            }

            if let score = attempt.selectedScore {
                sqlite3_bind_double(insertStatement, 6, Double(score))
            } else {
                sqlite3_bind_null(insertStatement, 6)
            }

            if let confidence = attempt.selectedConfidence {
                sqlite3_bind_double(insertStatement, 7, Double(confidence))
            } else {
                sqlite3_bind_null(insertStatement, 7)
            }

            if let method = attempt.selectedMethod {
                sqlite3_bind_text(insertStatement, 8, (method as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStatement, 8)
            }

            if let posX = attempt.selectedPositionX {
                sqlite3_bind_double(insertStatement, 9, Double(posX))
            } else {
                sqlite3_bind_null(insertStatement, 9)
            }

            if let posY = attempt.selectedPositionY {
                sqlite3_bind_double(insertStatement, 10, Double(posY))
            } else {
                sqlite3_bind_null(insertStatement, 10)
            }

            if let size = attempt.selectedSize {
                sqlite3_bind_double(insertStatement, 11, Double(size))
            } else {
                sqlite3_bind_null(insertStatement, 11)
            }

            sqlite3_bind_text(insertStatement, 12, (attempt.allCandidates as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 13, (attempt.allMethodsSummary as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 14, attempt.hasBrightText ? 1 : 0)

            if let color = attempt.dominantColor {
                sqlite3_bind_text(insertStatement, 15, (color as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStatement, 15)
            }

            sqlite3_bind_text(insertStatement, 16, (attempt.textPosition as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 17, Int32(attempt.processingTimeMs))
            sqlite3_bind_int(insertStatement, 18, Int32(attempt.numCandidates))
            sqlite3_bind_int(insertStatement, 19, Int32(attempt.numMethodsDetected))
            sqlite3_bind_text(insertStatement, 20, (attempt.consoleLog as NSString).utf8String, -1, nil)

            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("✅ OCR attempt logged to database")
            } else {
                print("❌ Could not insert OCR attempt")
            }
        } else {
            print("❌ INSERT statement could not be prepared")
        }

        sqlite3_finalize(insertStatement)
    }

    // MARK: - User Correction

    func logCorrection(originalText: String, correctedText: String) {
        guard DEBUG_OCR else { return }

        let updateSQL = """
        UPDATE ocr_attempts
        SET corrected_text = ?,
            was_correct = ?,
            correction_timestamp = CURRENT_TIMESTAMP
        WHERE selected_text = ?
        ORDER BY timestamp DESC
        LIMIT 1;
        """

        var updateStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(updateStatement, 1, (correctedText as NSString).utf8String, -1, nil)
            let wasCorrect = originalText.lowercased() == correctedText.lowercased() ? 1 : 0
            sqlite3_bind_int(updateStatement, 2, Int32(wasCorrect))
            sqlite3_bind_text(updateStatement, 3, (originalText as NSString).utf8String, -1, nil)

            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("✅ Correction logged: '\(originalText)' -> '\(correctedText)'")
            }
        }

        sqlite3_finalize(updateStatement)
    }

    // MARK: - Analysis Functions

    func getAccuracyStats() -> (total: Int, correct: Int, accuracy: Float) {
        let querySQL = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN was_correct = 1 THEN 1 ELSE 0 END) as correct
        FROM ocr_attempts
        WHERE was_correct IS NOT NULL;
        """

        var queryStatement: OpaquePointer?
        var total = 0
        var correct = 0

        if sqlite3_prepare_v2(db, querySQL, -1, &queryStatement, nil) == SQLITE_OK {
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                total = Int(sqlite3_column_int(queryStatement, 0))
                correct = Int(sqlite3_column_int(queryStatement, 1))
            }
        }

        sqlite3_finalize(queryStatement)

        let accuracy = total > 0 ? Float(correct) / Float(total) * 100 : 0
        return (total, correct, accuracy)
    }

    func getMethodPerformance() -> [(method: String, successRate: Float, count: Int)] {
        let querySQL = """
        SELECT
            selected_method,
            COUNT(*) as total,
            SUM(CASE WHEN was_correct = 1 THEN 1 ELSE 0 END) as correct
        FROM ocr_attempts
        WHERE was_correct IS NOT NULL AND selected_method IS NOT NULL
        GROUP BY selected_method
        ORDER BY correct DESC;
        """

        var queryStatement: OpaquePointer?
        var results: [(String, Float, Int)] = []

        if sqlite3_prepare_v2(db, querySQL, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let method = String(cString: sqlite3_column_text(queryStatement, 0))
                let total = Int(sqlite3_column_int(queryStatement, 1))
                let correct = Int(sqlite3_column_int(queryStatement, 2))
                let successRate = total > 0 ? Float(correct) / Float(total) * 100 : 0
                results.append((method, successRate, total))
            }
        }

        sqlite3_finalize(queryStatement)
        return results
    }

    func exportAllData() -> String {
        let querySQL = "SELECT * FROM ocr_attempts ORDER BY timestamp DESC LIMIT 100;"
        var queryStatement: OpaquePointer?
        var jsonData: [[String: Any]] = []

        if sqlite3_prepare_v2(db, querySQL, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                var row: [String: Any] = [:]

                // Extract all columns
                let columnCount = sqlite3_column_count(queryStatement)
                for i in 0..<columnCount {
                    let columnName = String(cString: sqlite3_column_name(queryStatement, i))

                    switch sqlite3_column_type(queryStatement, i) {
                    case SQLITE_INTEGER:
                        row[columnName] = Int(sqlite3_column_int(queryStatement, i))
                    case SQLITE_FLOAT:
                        row[columnName] = sqlite3_column_double(queryStatement, i)
                    case SQLITE_TEXT:
                        row[columnName] = String(cString: sqlite3_column_text(queryStatement, i))
                    case SQLITE_NULL:
                        row[columnName] = NSNull()
                    default:
                        break
                    }
                }

                jsonData.append(row)
            }
        }

        sqlite3_finalize(queryStatement)

        // Convert to JSON string
        if let jsonDataEncoded = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
           let jsonString = String(data: jsonDataEncoded, encoding: .utf8) {
            return jsonString
        }

        return "[]"
    }

    func printStats() {
        let stats = getAccuracyStats()
        print("\n" + String(repeating: "=", count: 60))
        print("📊 OCR ACCURACY STATISTICS")
        print(String(repeating: "=", count: 60))
        print("Total attempts with feedback: \(stats.total)")
        print("Correct: \(stats.correct)")
        print("Accuracy: \(String(format: "%.1f%%", stats.accuracy))")
        print("\n🔍 METHOD PERFORMANCE:")
        for (method, rate, count) in getMethodPerformance() {
            print("   \(method): \(String(format: "%.1f%%", rate)) (\(count) attempts)")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Helper Extensions

extension OCRLogger {
    func getTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<20: return "evening"
        default: return "night"
        }
    }

    func hashImage(_ image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            return UUID().uuidString
        }
        return imageData.base64EncodedString().prefix(32).description
    }
}
