//
//  OpenFoodFactsService.swift
//  Arovia
//
//  Client for the Open Food Facts product API (https://openfoodfacts.github.io/openfoodfacts-server/api/).
//  Read-only barcode lookup — this app never writes back to Open Food Facts.
//

import Foundation

enum OpenFoodFactsError: Error, LocalizedError {
    case invalidBarcode
    case productNotFound
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBarcode: "That doesn't look like a valid barcode."
        case .productNotFound: "No product found for this barcode in Open Food Facts. You can still add it as a custom food."
        case .network(let error): "Couldn't reach Open Food Facts: \(error.localizedDescription)"
        case .decoding: "Open Food Facts returned data in an unexpected format."
        }
    }
}

struct OpenFoodFactsService: Sendable {
    private let session: URLSession

    /// Open Food Facts' API guidelines ask every client to identify itself with an app name,
    /// version, and contact — shared IPs get rate-limited/blocked without one.
    private static let userAgent = "Arovia-iOS/1.0 (personal fitness app)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Looks up a scanned barcode. Throws `.productNotFound` if Open Food Facts has no record for
    /// it (common for local/unbranded products) — callers should fall back to manual entry.
    func fetchProduct(barcode: String) async throws -> FoodItem {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber), trimmed.count >= 6 else {
            throw OpenFoodFactsError.invalidBarcode
        }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json")
        components?.queryItems = [URLQueryItem(name: "fields", value: "product_name,brands,serving_size,serving_quantity,nutriments")]

        guard let url = components?.url else {
            throw OpenFoodFactsError.invalidBarcode
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw OpenFoodFactsError.network(error)
        }

        let decoded: OFFProductResponse
        do {
            decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        } catch {
            throw OpenFoodFactsError.decoding(error)
        }

        guard decoded.status == 1, let product = decoded.product else {
            throw OpenFoodFactsError.productNotFound
        }

        return product.asFoodItem(barcode: trimmed)
    }
}

// MARK: - Response models
// Deliberately lenient (everything optional) since Open Food Facts is community-sourced and
// individual fields are frequently missing for any given product.

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriments
    }

    func asFoodItem(barcode: String) -> FoodItem {
        let name = (productName?.isEmpty == false ? productName : nil) ?? "Unknown Product"
        let brandName = brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
        let servingQuantity = servingQuantity.flatMap { $0 > 0 ? $0 : nil }

        // Prefer OFF's real per-serving figures when present; otherwise scale the per-100g values
        // down to the serving size; if there's no serving size at all, fall back to "100g" as the
        // logged unit so the numbers stay meaningful rather than showing a whole package's worth.
        if let servingQuantity {
            let scale = servingQuantity / 100
            return FoodItem(
                name: name,
                brand: brandName,
                servingDescription: servingSize ?? "\(Int(servingQuantity))g",
                servingGrams: servingQuantity,
                calories: nutriments?.energyKcalServing ?? ((nutriments?.energyKcal100g ?? 0) * scale),
                proteinGrams: nutriments?.proteinsServing ?? ((nutriments?.proteins100g ?? 0) * scale),
                carbohydratesGrams: nutriments?.carbohydratesServing ?? ((nutriments?.carbohydrates100g ?? 0) * scale),
                fatGrams: nutriments?.fatServing ?? ((nutriments?.fat100g ?? 0) * scale),
                source: .barcode(code: barcode)
            )
        }

        return FoodItem(
            name: name,
            brand: brandName,
            servingDescription: "100g",
            servingGrams: 100,
            calories: nutriments?.energyKcal100g ?? 0,
            proteinGrams: nutriments?.proteins100g ?? 0,
            carbohydratesGrams: nutriments?.carbohydrates100g ?? 0,
            fatGrams: nutriments?.fat100g ?? 0,
            source: .barcode(code: barcode)
        )
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energyKcalServing: Double?
    let proteins100g: Double?
    let proteinsServing: Double?
    let carbohydrates100g: Double?
    let carbohydratesServing: Double?
    let fat100g: Double?
    let fatServing: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteins100g = "proteins_100g"
        case proteinsServing = "proteins_serving"
        case carbohydrates100g = "carbohydrates_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case fat100g = "fat_100g"
        case fatServing = "fat_serving"
    }
}
