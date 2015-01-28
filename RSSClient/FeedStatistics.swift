//
//  FeedStatistics.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/27/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class FeedStatistics {
    func estimateNextFeedTime(feed: Feed) -> (NSDate?, Double) { // Time, stddev
        // This could be much better done.
        // For example, some feeds only update on weekdays, which this would tell it to update
        // once every 7/5ths of a day, instead of once a day for 5 days, then not at all on the weekends.
        // But for now, it's ok.
        let times : [NSTimeInterval] = feed.allArticles().map {
            return $0.published.timeIntervalSince1970
            }.sorted { return $0 < $1 }
        
        if times.count < 2 {
            return (nil, 0)
        }
        
        func mean(values: [Double]) -> Double {
            return (values.reduce(0.0) { return $0 + $1 }) / Double(values.count)
        }
        
        var intervals : [NSTimeInterval] = []
        for (i, t) in enumerate(times) {
            if i == (times.count - 1) {
                break
            }
            intervals.append(fabs(times[i+1] - t))
        }
        let averageTimeInterval = mean(intervals)
        
        func stdev(values: [Double], average: Double) -> Double {
            return sqrt(mean(values.map { pow($0 - average, 2) }))
        }
        
        let standardDeviation = stdev(intervals, averageTimeInterval)
        
        let d = NSDate(timeIntervalSince1970: times.last! + averageTimeInterval)
        let end = d.dateByAddingTimeInterval(standardDeviation)
        
        if NSDate().compare(end) == NSComparisonResult.OrderedDescending {
            return (nil, 0)
        }
        
        return (NSDate(timeIntervalSince1970: times.last! + averageTimeInterval), standardDeviation)
    }
}