import XCTest
@testable import KlarCore

final class SubstanceDTOTests: XCTestCase {
    /// Costs are gone from Klar. An export written before that still carries `costPerUnitRaw`;
    /// it must import, with the field simply ignored.
    func testAnOlderExportWithACostStillDecodes() throws {
        let json = """
        {
          "id": "6B1F4D2E-8C3A-4E7B-9D10-2F5A6C7E8B90",
          "name": "Alkohol",
          "unit": "drink",
          "colorIndex": 0,
          "costPerUnitRaw": "5.50",
          "sortOrder": 0,
          "isArchived": false,
          "asksMorningAfter": true
        }
        """
        let dto = try JSONDecoder().decode(SubstanceDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.name, "Alkohol")

        let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: Any]
        XCTAssertNil(reencoded?["costPerUnitRaw"], "a new export carries no cost")
    }
}
