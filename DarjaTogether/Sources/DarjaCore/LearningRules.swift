import Foundation

/// Deterministic, device-only review rules. A recall tap is the learner's self-report.
enum LearningRules {
    static func nextReview(previous: WordReviewState?, remembered: Bool, at now: Date, calendar: Calendar = .current) -> (state: WordReviewState, earnsStar: Bool) {
        var review = previous ?? WordReviewState(dueDate: now, intervalDays: 0, successfulReviews: 0, lastReviewed: nil)
        let alreadyReviewedToday = review.lastReviewed.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        if remembered {
            if review.intervalDays == 0 || (!alreadyReviewedToday && review.dueDate <= now) {
                let intervals = [1, 3, 7, 14, 30]
                review.intervalDays = intervals[min(max(0, review.successfulReviews), intervals.count - 1)]
                review.successfulReviews += 1
                review.dueDate = calendar.date(byAdding: .day, value: review.intervalDays, to: now) ?? now.addingTimeInterval(86_400)
            }
        } else {
            review.intervalDays = 0
            review.successfulReviews = 0
            review.dueDate = now.addingTimeInterval(10 * 60)
        }
        review.lastReviewed = now
        return (review, remembered && !alreadyReviewedToday)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
