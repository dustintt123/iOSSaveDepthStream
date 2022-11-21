//
//  RecordSession.swift
//  ASLDepthCapture
//
//  Created by Ting Yu on 11/21/22.
//

import Foundation

struct RecordSession {
    static var current = RecordSession()
    
    var timestamp: String?
    
    func getCurrentTimestampString() -> String {
        let dateFromatter = DateFormatter()
        dateFromatter.dateStyle = .medium
        dateFromatter.timeStyle = .full
        return dateFromatter.string(from: Date())
    }
    
    mutating func newSession() {
        self.timestamp = getCurrentTimestampString()
    }
    
    mutating func endSession() {
        self.timestamp = nil
    }
}
