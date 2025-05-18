import Foundation
import CoreData

extension WeekendEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeekendEntity> {
        return NSFetchRequest<WeekendEntity>(entityName: "WeekendEntity")
    }

    @NSManaged public var recordIDValue: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var status: String?
    @NSManaged public var notes: String?
    @NSManaged public var location: String?
    @NSManaged public var weatherCondition: String?
    @NSManaged public var weatherTemperature: Double
    @NSManaged public var isHighTraffic: Bool
    @NSManaged public var plannedCount: Int16
    @NSManaged public var userRef: UserEntity?
} 