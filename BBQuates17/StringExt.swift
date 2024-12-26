//
//  StringExt.swift
//  BBQuates17
//
//  Created by Olha Pelypets on 12/12/2024.
//

import Foundation

extension String {
    func removeSpaces() -> String {
        self.replacingOccurrences(of: " ", with: "")
    }

    func removeCaseAndSpace() -> String {
        self.removeSpaces().lowercased()
    }
}
