//
//  NutritionBarcodeService.swift
//  Thea — AAI3-4
//
//  Barcode scanning pipeline:
//    AVCaptureMetadataOutput → EAN-13/UPC-A barcode
//    → OpenFoodFacts REST API v2 (world.openfoodfacts.org)
//    → HKQuantitySample (dietary energy) write to HealthKit
//
//  iOS/macOS: AVCapture for scanning; HealthKit for write.
//  Network: URLSession only (no SPM dependency).
//

import AVFoundation
import Foundation
import HealthKit
import os.log

#if canImport(UIKit)
    import UIKit
#endif

private let logger = Logger(subsystem: "app.thea", category: "NutritionBarcodeService")

// MARK: - Nutrition Product

struct NutritionProduct: Sendable {
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let barcode: String
    let name: String
    let brand: String
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let servingSizeG: Double      // grams per serving
    let caloriesPerServing: Double // kcal per serving
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let fiberG: Double
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let sodiumMg: Double
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let nutriScore: String?       // "a"–"e" or nil
}

// MARK: - NutritionBarcodeService

/// Singleton service for barcode → nutrition data → HealthKit logging.
@MainActor
final class NutritionBarcodeService: NSObject, ObservableObject {

    static let shared = NutritionBarcodeService()

    // MARK: - Published State

    @Published private(set) var isScanning = false
    @Published private(set) var lastProduct: NutritionProduct?
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    @Published private(set) var lastError: String?
    @Published private(set) var healthKitAuthorized = false

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var captureSession: AVCaptureSession?
    private var onBarcodeDetected: ((String) -> Void)?

    private static let offBaseURL = "https://world.openfoodfacts.org/api/v2/product/"

    override private init() {
        super.init()
        Task { await requestHealthKitAuthorization() }
    }

    // MARK: - HealthKit Authorization

    private func requestHealthKitAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available on this device")
            return
        }
        let energyType = HKQuantityType(.dietaryEnergyConsumed)
        let proteinType = HKQuantityType(.dietaryProtein)
        let fatType = HKQuantityType(.dietaryFatTotal)
        let carbsType = HKQuantityType(.dietaryCarbohydrates)

        do {
            try await healthStore.requestAuthorization(
                toShare: [energyType, proteinType, fatType, carbsType],
                read: [energyType]
            )
            healthKitAuthorized = true
            logger.info("NutritionBarcodeService: HealthKit authorized")
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Barcode Scanning

    /// Starts the AVCapture session and calls the handler when a barcode is found.
    /// The caller is responsible for providing a preview layer to the user.
    func startScanning(onBarcode handler: @escaping (String) -> Void) {
        guard !isScanning else { return }
        isScanning = true
        onBarcodeDetected = handler
        lastError = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.configureCaptureSession()
        }
    }

    /// Stops the running capture session.
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        isScanning = false
        logger.info("NutritionBarcodeService: scanning stopped")
    }

    private func configureCaptureSession() async {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            await MainActor.run {
                self.lastError = "Camera not available"
                self.isScanning = false
            }
            return
        }

        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            await MainActor.run {
                self.lastError = "Cannot add metadata output"
                self.isScanning = false
            }
            return
        }
        session.addOutput(metadataOutput)

        // EAN-13 and UPC-A cover most food products globally
        metadataOutput.metadataObjectTypes = [.ean13, .upce]
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

        await MainActor.run { self.captureSession = session }
        session.startRunning()
        logger.info("NutritionBarcodeService: capture session running")
    }

    // MARK: - Barcode → Product Lookup

    /// Fetch product nutrition from OpenFoodFacts by barcode.
    func lookupBarcode(_ barcode: String) async throws -> NutritionProduct {
        logger.info("NutritionBarcodeService: looking up barcode \(barcode)")

        let url = URL(string: "\(Self.offBaseURL)\(barcode).json?fields=product_name,brands,serving_size,nutriments,nutriscore_grade")!
        var request = URLRequest(url: url)
        request.setValue("Thea/1.0 (contact@theathe.app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BarcodeLookupError.networkError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            throw BarcodeLookupError.productNotFound(barcode)
        }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]

        func nutriDouble(_ key: String) -> Double {
            (nutriments[key] as? Double) ?? (nutriments["\(key)_100g"] as? Double ?? 0)
        }

        let product_ = NutritionProduct(
            barcode: barcode,
            name: (product["product_name"] as? String) ?? "Unknown",
            brand: (product["brands"] as? String) ?? "",
            servingSizeG: Double((product["serving_size"] as? String)?.filter { $0.isNumber || $0 == "." } ?? "100") ?? 100,
            caloriesPerServing: nutriDouble("energy-kcal_serving").nonZeroOr(nutriDouble("energy-kcal") * 100 / 100),
            proteinG: nutriDouble("proteins_serving").nonZeroOr(nutriDouble("proteins") * 100 / 100),
            fatG: nutriDouble("fat_serving").nonZeroOr(nutriDouble("fat") * 100 / 100),
            carbsG: nutriDouble("carbohydrates_serving").nonZeroOr(nutriDouble("carbohydrates") * 100 / 100),
            fiberG: nutriDouble("fiber_serving").nonZeroOr(nutriDouble("fiber") * 100 / 100),
            sodiumMg: nutriDouble("sodium_serving").nonZeroOr(nutriDouble("sodium") * 100 / 100) * 1000,
            nutriScore: product["nutriscore_grade"] as? String
        )

        logger.info("NutritionBarcodeService: found '\(product_.name)' — \(product_.caloriesPerServing) kcal/serving")
        return product_
    }

    // MARK: - HealthKit Write

    /// Log the scanned product's calories (and macros) to HealthKit.
    /// - Parameters:
    ///   - product: The nutrition product to log.
    ///   - servings: Number of servings consumed (default: 1).
    ///   - date: The meal time (default: now).
    func logToHealthKit(_ product: NutritionProduct, servings: Double = 1, date: Date = Date()) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw BarcodeLookupError.healthKitUnavailable
        }

        var samples: [HKQuantitySample] = []
        let start = date
        let end = date

        // Dietary energy (calories)
        let kcal = product.caloriesPerServing * servings
        if kcal > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryEnergyConsumed),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: start, end: end
            ))
        }

        // Protein
        let proteinG = product.proteinG * servings
        if proteinG > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryProtein),
                quantity: HKQuantity(unit: .gram(), doubleValue: proteinG),
                start: start, end: end
            ))
        }

        // Fat
        let fatG = product.fatG * servings
        if fatG > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryFatTotal),
                quantity: HKQuantity(unit: .gram(), doubleValue: fatG),
                start: start, end: end
            ))
        }

        // Carbohydrates
        let carbsG = product.carbsG * servings
        if carbsG > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryCarbohydrates),
                quantity: HKQuantity(unit: .gram(), doubleValue: carbsG),
                start: start, end: end
            ))
        }

        guard !samples.isEmpty else {
            throw BarcodeLookupError.noNutritionData(product.name)
        }

        try await healthStore.save(samples)
        logger.info("NutritionBarcodeService: logged \(samples.count) HealthKit samples for '\(product.name)'")
    }

    // MARK: - Convenience: Scan → Lookup → Log

    /// Full pipeline: scan barcode → fetch product → log to HealthKit.
    func scanAndLog(servings: Double = 1, date: Date = Date()) async {
        startScanning { [weak self] barcode in
            guard let self else { return }
            Task { @MainActor in
                self.stopScanning()
                do {
                    let product = try await self.lookupBarcode(barcode)
                    self.lastProduct = product
                    try await self.logToHealthKit(product, servings: servings, date: date)
                } catch {
                    self.lastError = error.localizedDescription
                    logger.error("NutritionBarcodeService: pipeline failed — \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension NutritionBarcodeService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let meta = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = meta.stringValue else { return }

        Task { @MainActor [weak self] in
            self?.onBarcodeDetected?(barcode)
        }
    }
}

// MARK: - Errors

enum BarcodeLookupError: LocalizedError {
    case productNotFound(String)
    case networkError(String)
    case healthKitUnavailable
    case noNutritionData(String)

    var errorDescription: String? {
        switch self {
        case .productNotFound(let code):   return "Product not found in OpenFoodFacts (barcode: \(code))"
        case .networkError(let msg):       return "Network error: \(msg)"
        case .healthKitUnavailable:        return "HealthKit is not available on this device."
        case .noNutritionData(let name):   return "No nutrition data to log for '\(name)'."
        }
    }
}

// MARK: - Double helper

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
