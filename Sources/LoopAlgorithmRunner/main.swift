//
//  main.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 9/30/24.
//

import Foundation
import LoopAlgorithm

// Function to read and decode the JSON file
func readInputFile(_ path: String) throws -> AlgorithmInputFixture {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(AlgorithmInputFixture.self, from: data)
}

// Main execution logic
func main() {
    guard CommandLine.arguments.count > 1 else {
        print("Usage: LoopAlgorithmRunner <input_file_path>")
        exit(1)
    }

    let inputFilePath = CommandLine.arguments[1]

    do {
        let input = try readInputFile(inputFilePath)
        let output = LoopAlgorithm.run(input: input)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(output)

        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

// Run the main function
main()
