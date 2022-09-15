//
//  HabitStatistics.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 12/09/2022.
//

import Foundation

struct HabitStatistics {
    var habit: Habit
    var userCounts: [UserCount]
}



extension HabitStatistics: Codable {}
