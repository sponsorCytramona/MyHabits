//
//  LoggedHabbit.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 13/09/2022.
//

import Foundation

struct LoggedHabiit {
    let userID: String
    let habitName: String
    let timestamp: Date
}

extension LoggedHabiit: Codable {}
