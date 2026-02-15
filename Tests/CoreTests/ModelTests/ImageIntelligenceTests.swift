// ImageIntelligenceTests.swift
// Tests for ImageIntelligence types and logic
// SPM-compatible — uses standalone test doubles mirroring production types

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestImageOperation: String, CaseIterable, Codable {
    case removeBackground = "Remove Background"
    case upscale = "Upscale"
    case convertFormat = "Convert Format"
    case compress = "Compress"
    case resize = "Resize"
    case crop = "Crop"
    case adjustColors = "Adjust Colors"
    case extractText = "Extract Text (OCR)"
    case analyzeContent = "Analyze Content"
    case generateThumbnail = "Generate Thumbnail"

    var icon: String {
        switch self {
        case .removeBackground: "person.crop.rectangle"
        case .upscale: "arrow.up.left.and.arrow.down.right"
        case .convertFormat: "arrow.triangle.2.circlepath"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .resize: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .crop: "crop"
        case .adjustColors: "slider.horizontal.3"
        case .extractText: "doc.text.viewfinder"
        case .analyzeContent: "eye"
        case .generateThumbnail: "photo"
        }
    }

    var description: String {
        switch self {
        case .removeBackground: "Remove background using subject isolation"
        case .upscale: "Increase resolution using AI upscaling"
        case .convertFormat: "Convert between PNG, JPEG, HEIC, TIFF, WebP"
        case .compress: "Reduce file size with quality control"
        case .resize: "Resize to specific dimensions"
        case .crop: "Crop to selection or aspect ratio"
        case .adjustColors: "Adjust brightness, contrast, saturation"
        case .extractText: "Extract text from image using OCR"
        case .analyzeContent: "Identify objects, scenes, and faces"
        case .generateThumbnail: "Create a thumbnail at specified size"
        }
    }
}

private enum TestImageFormat: String, CaseIterable, Codable {
    case png, jpeg, heic, tiff, webp

    var fileExtension: String { rawValue }
    var displayName: String { rawValue.uppercased() }

    var mimeType: String {
        switch self {
        case .png: "image/png"
        case .jpeg: "image/jpeg"
        case .heic: "image/heic"
        case .tiff: "image/tiff"
        case .webp: "image/webp"
        }
    }
}

private struct TestColorAdjustment: Codable {
    var brightness: Double
    var contrast: Double
    var saturation: Double
    var sharpness: Double

    static let identity = TestColorAdjustment(brightness: 0, contrast: 1, saturation: 1, sharpness: 0)
}

private struct TestImageDimensions: Codable {
    let width: Int
    let height: Int

    var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }

    var megapixels: Double {
        Double(width * height) / 1_000_000
    }

    var displayString: String {
        "\(width) × \(height)"
    }
}

private struct TestBoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

private struct TestDominantColor: Codable, Identifiable {
    let id: UUID
    let red: Double
    let green: Double
    let blue: Double
    let percentage: Double

    var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init(red: Double, green: Double, blue: Double, percentage: Double) {
        self.id = UUID()
        self.red = red; self.green = green; self.blue = blue; self.percentage = percentage
    }
}

private struct TestImageDetectedObject: Codable, Identifiable {
    let id: UUID
    let label: String
    let confidence: Float
    let boundingBox: TestBoundingBox

    init(label: String, confidence: Float, boundingBox: TestBoundingBox = TestBoundingBox()) {
        self.id = UUID()
        self.label = label; self.confidence = confidence; self.boundingBox = boundingBox
    }
}

private struct TestImageAnalysisResult: Codable, Identifiable {
    let id: UUID
    let detectedObjects: [TestImageDetectedObject]
    let dominantColors: [TestDominantColor]
    let textContent: String?
    let sceneClassification: String?
    let faceCount: Int
    let dimensions: TestImageDimensions
    let fileSize: Int64
    let format: String
    let analyzedAt: Date

    init(
        detectedObjects: [TestImageDetectedObject] = [],
        dominantColors: [TestDominantColor] = [],
        textContent: String? = nil,
        sceneClassification: String? = nil,
        faceCount: Int = 0,
        dimensions: TestImageDimensions = TestImageDimensions(width: 0, height: 0),
        fileSize: Int64 = 0,
        format: String = "unknown"
    ) {
        self.id = UUID()
        self.detectedObjects = detectedObjects
        self.dominantColors = dominantColors
        self.textContent = textContent
        self.sceneClassification = sceneClassification
        self.faceCount = faceCount
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.format = format
        self.analyzedAt = Date()
    }
}

private struct TestProcessingRecord: Codable, Identifiable {
    let id: UUID
    let operation: TestImageOperation
    let fileName: String
    let inputSize: Int64
    let outputSize: Int64
    let processedAt: Date

    init(operation: TestImageOperation, fileName: String, inputSize: Int64, outputSize: Int64) {
        self.id = UUID()
        self.operation = operation
        self.fileName = fileName
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.processedAt = Date()
    }

    var compressionRatio: Double {
        guard inputSize > 0 else { return 0 }
        return 1.0 - (Double(outputSize) / Double(inputSize))
    }
}

private enum TestImageIntelligenceError: Error, LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case processingFailed(String)
    case invalidDimensions
    case ciContextCreationFailed
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): "Image file not found: \(path)"
        case .unsupportedFormat(let fmt): "Unsupported image format: \(fmt)"
        case .processingFailed(let msg): "Image processing failed: \(msg)"
        case .invalidDimensions: "Invalid image dimensions"
        case .ciContextCreationFailed: "Failed to create CoreImage context"
        case .visionRequestFailed(let msg): "Vision request failed: \(msg)"
        }
    }
}

private func testFormatFileSize(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024, unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    if unitIndex == 0 { return "\(bytes) B" }
    return String(format: "%.1f %@", value, units[unitIndex])
}

// MARK: - Tests

@Suite("ImageOperation")
struct ImageOperationTests {
    @Test func allCases() {
        #expect(TestImageOperation.allCases.count == 10)
    }

    @Test func uniqueRawValues() {
        let raw = TestImageOperation.allCases.map(\.rawValue)
        #expect(Set(raw).count == raw.count)
    }

    @Test func uniqueIcons() {
        let icons = TestImageOperation.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func descriptionsNonEmpty() {
        for op in TestImageOperation.allCases {
            #expect(!op.description.isEmpty)
        }
    }

    @Test func codableRoundtrip() throws {
        for op in TestImageOperation.allCases {
            let data = try JSONEncoder().encode(op)
            let decoded = try JSONDecoder().decode(TestImageOperation.self, from: data)
            #expect(decoded == op)
        }
    }
}

@Suite("ImageFormat")
struct ImageFormatTests {
    @Test func allCases() {
        #expect(TestImageFormat.allCases.count == 5)
    }

    @Test func fileExtensions() {
        #expect(TestImageFormat.png.fileExtension == "png")
        #expect(TestImageFormat.jpeg.fileExtension == "jpeg")
        #expect(TestImageFormat.heic.fileExtension == "heic")
        #expect(TestImageFormat.tiff.fileExtension == "tiff")
        #expect(TestImageFormat.webp.fileExtension == "webp")
    }

    @Test func displayNames() {
        #expect(TestImageFormat.png.displayName == "PNG")
        #expect(TestImageFormat.jpeg.displayName == "JPEG")
        #expect(TestImageFormat.heic.displayName == "HEIC")
    }

    @Test func mimeTypes() {
        #expect(TestImageFormat.png.mimeType == "image/png")
        #expect(TestImageFormat.jpeg.mimeType == "image/jpeg")
        #expect(TestImageFormat.heic.mimeType == "image/heic")
        #expect(TestImageFormat.tiff.mimeType == "image/tiff")
        #expect(TestImageFormat.webp.mimeType == "image/webp")
    }

    @Test func uniqueMimeTypes() {
        let mimes = TestImageFormat.allCases.map(\.mimeType)
        #expect(Set(mimes).count == mimes.count)
    }
}

@Suite("ImageDimensions")
struct ImageDimensionsTests {
    @Test func aspectRatioLandscape() {
        let dims = TestImageDimensions(width: 1920, height: 1080)
        #expect(abs(dims.aspectRatio - 16.0 / 9.0) < 0.01)
    }

    @Test func aspectRatioPortrait() {
        let dims = TestImageDimensions(width: 1080, height: 1920)
        #expect(abs(dims.aspectRatio - 9.0 / 16.0) < 0.01)
    }

    @Test func aspectRatioSquare() {
        let dims = TestImageDimensions(width: 1000, height: 1000)
        #expect(dims.aspectRatio == 1.0)
    }

    @Test func aspectRatioZeroHeight() {
        let dims = TestImageDimensions(width: 100, height: 0)
        #expect(dims.aspectRatio == 0)
    }

    @Test func megapixels4K() {
        let dims = TestImageDimensions(width: 3840, height: 2160)
        #expect(abs(dims.megapixels - 8.2944) < 0.01)
    }

    @Test func megapixelsSmall() {
        let dims = TestImageDimensions(width: 100, height: 100)
        #expect(dims.megapixels == 0.01)
    }

    @Test func displayString() {
        let dims = TestImageDimensions(width: 1920, height: 1080)
        #expect(dims.displayString == "1920 × 1080")
    }

    @Test func codableRoundtrip() throws {
        let dims = TestImageDimensions(width: 4000, height: 3000)
        let data = try JSONEncoder().encode(dims)
        let decoded = try JSONDecoder().decode(TestImageDimensions.self, from: data)
        #expect(decoded.width == 4000)
        #expect(decoded.height == 3000)
    }
}

@Suite("DominantColor")
struct DominantColorTests {
    @Test func hexStringBlack() {
        let color = TestDominantColor(red: 0, green: 0, blue: 0, percentage: 1.0)
        #expect(color.hexString == "#000000")
    }

    @Test func hexStringWhite() {
        let color = TestDominantColor(red: 1, green: 1, blue: 1, percentage: 1.0)
        #expect(color.hexString == "#FFFFFF")
    }

    @Test func hexStringRed() {
        let color = TestDominantColor(red: 1, green: 0, blue: 0, percentage: 0.5)
        #expect(color.hexString == "#FF0000")
    }

    @Test func hexStringMidGrey() {
        let color = TestDominantColor(red: 0.5, green: 0.5, blue: 0.5, percentage: 0.3)
        #expect(color.hexString == "#7F7F7F" || color.hexString == "#808080")
    }

    @Test func uniqueIDs() {
        let a = TestDominantColor(red: 1, green: 0, blue: 0, percentage: 0.5)
        let b = TestDominantColor(red: 1, green: 0, blue: 0, percentage: 0.5)
        #expect(a.id != b.id)
    }
}

@Suite("BoundingBox")
struct BoundingBoxTests {
    @Test func defaults() {
        let box = TestBoundingBox()
        #expect(box.x == 0)
        #expect(box.y == 0)
        #expect(box.width == 0)
        #expect(box.height == 0)
    }

    @Test func custom() {
        let box = TestBoundingBox(x: 10, y: 20, width: 100, height: 200)
        #expect(box.x == 10)
        #expect(box.y == 20)
        #expect(box.width == 100)
        #expect(box.height == 200)
    }

    @Test func codableRoundtrip() throws {
        let box = TestBoundingBox(x: 0.1, y: 0.2, width: 0.5, height: 0.5)
        let data = try JSONEncoder().encode(box)
        let decoded = try JSONDecoder().decode(TestBoundingBox.self, from: data)
        #expect(decoded.x == 0.1)
        #expect(decoded.width == 0.5)
    }
}

@Suite("DetectedObject")
struct DetectedObjectTests {
    @Test func creation() {
        let obj = TestImageDetectedObject(label: "cat", confidence: 0.95)
        #expect(obj.label == "cat")
        #expect(obj.confidence == 0.95)
    }

    @Test func uniqueIDs() {
        let a = TestImageDetectedObject(label: "dog", confidence: 0.8)
        let b = TestImageDetectedObject(label: "dog", confidence: 0.8)
        #expect(a.id != b.id)
    }

    @Test func defaultBoundingBox() {
        let obj = TestImageDetectedObject(label: "person", confidence: 0.9)
        #expect(obj.boundingBox.x == 0)
        #expect(obj.boundingBox.y == 0)
    }

    @Test func customBoundingBox() {
        let box = TestBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let obj = TestImageDetectedObject(label: "car", confidence: 0.7, boundingBox: box)
        #expect(obj.boundingBox.x == 0.1)
        #expect(obj.boundingBox.width == 0.3)
    }
}

@Suite("ColorAdjustment")
struct ColorAdjustmentTests {
    @Test func identityDefaults() {
        let adj = TestColorAdjustment.identity
        #expect(adj.brightness == 0)
        #expect(adj.contrast == 1)
        #expect(adj.saturation == 1)
        #expect(adj.sharpness == 0)
    }

    @Test func customValues() {
        let adj = TestColorAdjustment(brightness: 0.5, contrast: 1.5, saturation: 0.8, sharpness: 0.3)
        #expect(adj.brightness == 0.5)
        #expect(adj.contrast == 1.5)
        #expect(adj.saturation == 0.8)
        #expect(adj.sharpness == 0.3)
    }

    @Test func codableRoundtrip() throws {
        let adj = TestColorAdjustment(brightness: -0.3, contrast: 2.0, saturation: 1.5, sharpness: 0.7)
        let data = try JSONEncoder().encode(adj)
        let decoded = try JSONDecoder().decode(TestColorAdjustment.self, from: data)
        #expect(decoded.brightness == -0.3)
        #expect(decoded.contrast == 2.0)
    }
}

@Suite("ImageAnalysisResult")
struct ImageAnalysisResultTests {
    @Test func defaults() {
        let result = TestImageAnalysisResult()
        #expect(result.detectedObjects.isEmpty)
        #expect(result.dominantColors.isEmpty)
        #expect(result.textContent == nil)
        #expect(result.sceneClassification == nil)
        #expect(result.faceCount == 0)
        #expect(result.dimensions.width == 0)
        #expect(result.fileSize == 0)
        #expect(result.format == "unknown")
    }

    @Test func fullResult() {
        let obj = TestImageDetectedObject(label: "cat", confidence: 0.9)
        let color = TestDominantColor(red: 0.5, green: 0.3, blue: 0.1, percentage: 0.6)
        let dims = TestImageDimensions(width: 1920, height: 1080)

        let result = TestImageAnalysisResult(
            detectedObjects: [obj],
            dominantColors: [color],
            textContent: "Hello world",
            sceneClassification: "indoor",
            faceCount: 2,
            dimensions: dims,
            fileSize: 1024 * 1024,
            format: "jpeg"
        )

        #expect(result.detectedObjects.count == 1)
        #expect(result.dominantColors.count == 1)
        #expect(result.textContent == "Hello world")
        #expect(result.sceneClassification == "indoor")
        #expect(result.faceCount == 2)
        #expect(result.dimensions.width == 1920)
        #expect(result.fileSize == 1024 * 1024)
        #expect(result.format == "jpeg")
    }

    @Test func uniqueIDs() {
        let a = TestImageAnalysisResult()
        let b = TestImageAnalysisResult()
        #expect(a.id != b.id)
    }
}

@Suite("ProcessingRecord")
struct ProcessingRecordTests {
    @Test func creation() {
        let record = TestProcessingRecord(operation: .compress, fileName: "photo.jpg", inputSize: 5_000_000, outputSize: 1_000_000)
        #expect(record.operation == .compress)
        #expect(record.fileName == "photo.jpg")
        #expect(record.inputSize == 5_000_000)
        #expect(record.outputSize == 1_000_000)
    }

    @Test func compressionRatioPositive() {
        let record = TestProcessingRecord(operation: .compress, fileName: "a.jpg", inputSize: 1000, outputSize: 300)
        #expect(abs(record.compressionRatio - 0.7) < 0.001)
    }

    @Test func compressionRatioZeroInput() {
        let record = TestProcessingRecord(operation: .compress, fileName: "a.jpg", inputSize: 0, outputSize: 100)
        #expect(record.compressionRatio == 0)
    }

    @Test func compressionRatioNoChange() {
        let record = TestProcessingRecord(operation: .convertFormat, fileName: "a.png", inputSize: 1000, outputSize: 1000)
        #expect(record.compressionRatio == 0)
    }

    @Test func compressionRatioLargerOutput() {
        let record = TestProcessingRecord(operation: .upscale, fileName: "a.jpg", inputSize: 1000, outputSize: 2000)
        #expect(record.compressionRatio < 0)
    }

    @Test func codableRoundtrip() throws {
        let record = TestProcessingRecord(operation: .resize, fileName: "test.png", inputSize: 500, outputSize: 200)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TestProcessingRecord.self, from: data)
        #expect(decoded.operation == .resize)
        #expect(decoded.fileName == "test.png")
        #expect(decoded.inputSize == 500)
        #expect(decoded.outputSize == 200)
    }

    @Test func uniqueIDs() {
        let a = TestProcessingRecord(operation: .compress, fileName: "a.jpg", inputSize: 100, outputSize: 50)
        let b = TestProcessingRecord(operation: .compress, fileName: "a.jpg", inputSize: 100, outputSize: 50)
        #expect(a.id != b.id)
    }
}

@Suite("ImageIntelligenceError")
struct ImageIntelligenceErrorTests {
    @Test func fileNotFound() {
        let err = TestImageIntelligenceError.fileNotFound("/tmp/missing.jpg")
        #expect(err.errorDescription?.contains("missing.jpg") == true)
    }

    @Test func unsupportedFormat() {
        let err = TestImageIntelligenceError.unsupportedFormat("bmp")
        #expect(err.errorDescription?.contains("bmp") == true)
    }

    @Test func processingFailed() {
        let err = TestImageIntelligenceError.processingFailed("out of memory")
        #expect(err.errorDescription?.contains("out of memory") == true)
    }

    @Test func invalidDimensions() {
        let err = TestImageIntelligenceError.invalidDimensions
        #expect(err.errorDescription?.contains("dimensions") == true)
    }

    @Test func ciContextFailed() {
        let err = TestImageIntelligenceError.ciContextCreationFailed
        #expect(err.errorDescription?.contains("CoreImage") == true)
    }

    @Test func visionRequestFailed() {
        let err = TestImageIntelligenceError.visionRequestFailed("timeout")
        #expect(err.errorDescription?.contains("timeout") == true)
    }
}

@Suite("Image File Size Formatting")
struct ImageFileSizeFormattingTests {
    @Test func bytes() {
        #expect(testFormatFileSize(500) == "500 B")
    }

    @Test func kilobytes() {
        let result = testFormatFileSize(1536)
        #expect(result == "1.5 KB")
    }

    @Test func megabytes() {
        let result = testFormatFileSize(5 * 1024 * 1024)
        #expect(result == "5.0 MB")
    }

    @Test func gigabytes() {
        let result = testFormatFileSize(2 * 1024 * 1024 * 1024)
        #expect(result == "2.0 GB")
    }

    @Test func zero() {
        #expect(testFormatFileSize(0) == "0 B")
    }
}

@Suite("History Limit")
struct HistoryLimitTests {
    @Test func historyCapAt500() {
        var records: [TestProcessingRecord] = []
        for i in 0..<510 {
            records.append(TestProcessingRecord(operation: .compress, fileName: "file\(i).jpg", inputSize: 100, outputSize: 50))
        }
        if records.count > 500 {
            records = Array(records.suffix(500))
        }
        #expect(records.count == 500)
        // Newest items kept
        #expect(records.last?.fileName == "file509.jpg")
        #expect(records.first?.fileName == "file10.jpg")
    }

    @Test func totalBytesProcessed() {
        let records = [
            TestProcessingRecord(operation: .compress, fileName: "a.jpg", inputSize: 1000, outputSize: 500),
            TestProcessingRecord(operation: .resize, fileName: "b.png", inputSize: 2000, outputSize: 800),
            TestProcessingRecord(operation: .convertFormat, fileName: "c.heic", inputSize: 3000, outputSize: 3000)
        ]
        let total = records.reduce(Int64(0)) { $0 + $1.inputSize }
        #expect(total == 6000)
    }

    @Test func totalBytesSaved() {
        let records = [
            TestProcessingRecord(operation: .compress, fileName: "a.jpg", inputSize: 1000, outputSize: 300),
            TestProcessingRecord(operation: .upscale, fileName: "b.png", inputSize: 500, outputSize: 2000)
        ]
        let saved = records.reduce(Int64(0)) { $0 + max(0, $1.inputSize - $1.outputSize) }
        #expect(saved == 700) // Only counts positive savings
    }
}
