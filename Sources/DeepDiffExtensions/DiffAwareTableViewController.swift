import Foundation
import UIKit
import RxSwift
import RxCocoa
import Logger
import DeepDiff

public protocol DiffAwareTableViewController: AnyObject {

    associatedtype SectionType: DiffAwareSectionModelType

    var tableView: UITableView! { get }
    var lockScheduler: ConcurrentDispatchQueueScheduler { get }
    var tableViewUpdateGroup: DispatchGroup { get }
    var disposeBag: DisposeBag { get }
    var sections: [SectionType] { get set }
    var insertionAnimation: UITableView.RowAnimation { get }
    var deletionAnimation: UITableView.RowAnimation { get }
    var replacementAnimation: UITableView.RowAnimation { get }
    var sectionInsertionAnimation: UITableView.RowAnimation { get }
    var sectionDeletionAnimation: UITableView.RowAnimation { get }
    var sourceName: String { get }
    func bindTableView(sections: BehaviorRelay<[SectionType]>)
}

public extension DiffAwareTableViewController  {

    var insertionAnimation: UITableView.RowAnimation { return .automatic }
    var deletionAnimation: UITableView.RowAnimation { return .automatic }
    var replacementAnimation: UITableView.RowAnimation { return .none }
    var sectionInsertionAnimation: UITableView.RowAnimation { return .automatic }
    var sectionDeletionAnimation: UITableView.RowAnimation { return .automatic }
    var sourceName: String { return "TableViewDebug" }

    func bindTableView(sections: BehaviorRelay<[SectionType]>) {

        let sourceName = self.sourceName
        sections.distinctUntilChanged().skip(1).observe(on: lockScheduler).map { [weak self] (updatedSections) -> CollectionUpdates<SectionType>?  in

            if self == nil { return nil }
            sdn_log(object: "acquire lock", category: Category.threadLock, logType: .debug)
            self?.tableViewUpdateGroup.wait()
            if self == nil { return nil }
            self?.tableViewUpdateGroup.enter()
            sdn_log(object: "lock acquired", category: Category.threadLock, logType: .debug)

            guard let existingSections = self?.sections else { return nil }

            let changes = SectionChangesWithIndexPath(existingSections: existingSections, updatedSections: updatedSections)

            return CollectionUpdates(changes: changes, sections: updatedSections)
        }.compactMap { $0 }.observe(on: MainScheduler.instance).bind { [weak self] (updates) in

            guard let self = self else { return }

            sdn_log(object: "Inserted Sections: \(updates.changes.sectionInserts)", category: Category.custom(categoryName: sourceName),logType: .debug)
            sdn_log(object: "Deleted Sections: \(updates.changes.sectionDeletes)", category: Category.custom(categoryName: sourceName), logType: .debug)
            sdn_log(object: "Inserted Rows: \(updates.changes.inserts)", category: Category.custom(categoryName: sourceName), logType: .debug)
            sdn_log(object: "Deleted Rows: \(updates.changes.deletes)", category: Category.custom(categoryName: sourceName), logType: .debug)
            sdn_log(object: "Replaced Rows: \(updates.changes.replaces)", category: Category.custom(categoryName: sourceName), logType: .debug)
            sdn_log(object: "Moved Rows: \(updates.changes.moves)", category: Category.custom(categoryName: sourceName), logType: .debug)

            self.tableView.reload(changesWithIndexPath: updates.changes,
                                   insertionAnimation: self.insertionAnimation,
                                   deletionAnimation: self.deletionAnimation,
                                   replacementAnimation: self.replacementAnimation,
                                   sectionInsertionAnimation: self.sectionInsertionAnimation,
                                   sectionDeletionAnimation: self.sectionDeletionAnimation,
                                   updateData: { [weak self] in

                                    sdn_log(object: "update data called", category: Category.custom(categoryName: sourceName),logType: .debug)
                                    self?.sections = updates.sections

            }, completion: { [weak self] (completed) in

                sdn_log(object: "update complete", category: Category.custom(categoryName: sourceName),logType: .debug)
                sdn_log(object: "lock released", category: Category.threadLock, logType: .debug)
                self?.tableViewUpdateGroup.leave()
            })
        }.disposed(by: disposeBag)
    }
}
