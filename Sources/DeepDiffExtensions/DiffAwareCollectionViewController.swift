import Foundation
import UIKit
import RxSwift
import RxCocoa
import Logger
import DeepDiff

public protocol DiffAwareCollectionViewController: AnyObject {

    associatedtype SectionType: DiffAwareSectionModelType

    var collectionView: UICollectionView! { get }
    var lockScheduler: ConcurrentDispatchQueueScheduler { get }
    var collectionViewUpdateGroup: DispatchGroup { get }
    var disposeBag: DisposeBag { get }
    var sections: [SectionType] { get set }

    func updateLayoutCache(indexPaths: [IndexPath])
    func clearLayoutCache()
    func bindCollectionView(sections: BehaviorRelay<[SectionType]>)
}

public extension DiffAwareCollectionViewController {

    func bindCollectionView(sections: BehaviorRelay<[SectionType]>) {

        sections.distinctUntilChanged().skip(1).observe(on: lockScheduler).map { [weak self] (updatedSections) -> CollectionUpdates<SectionType>? in

            if self == nil { return nil }
            sdn_log(object: "acquire lock", category: Category.threadLock, logType: .debug)
            self?.collectionViewUpdateGroup.wait()
            if self == nil { return nil }
            self?.collectionViewUpdateGroup.enter()
            sdn_log(object: "lock acquired", category: Category.threadLock, logType: .debug)

            guard let existingSections = self?.sections else { return nil }

            let changes = SectionChangesWithIndexPath(existingSections: existingSections, updatedSections: updatedSections)

            return CollectionUpdates(changes: changes, sections: updatedSections)
        }.compactMap { $0 }.observe(on: MainScheduler.instance).bind { [weak self] (updates) in

            guard let self = self else { return }

            sdn_log(object: "Inserted Sections: \(updates.changes.sectionInserts)", category: Category.custom(categoryName: "CollectionViewDebug"),logType: .debug)
            sdn_log(object: "Deleted Sections: \(updates.changes.sectionDeletes)", category: Category.custom(categoryName: "CollectionViewDebug"), logType: .debug)
            sdn_log(object: "Inserted Items: \(updates.changes.inserts)", category: Category.custom(categoryName: "CollectionViewDebug"), logType: .debug)
            sdn_log(object: "Deleted Items: \(updates.changes.deletes)", category: Category.custom(categoryName: "CollectionViewDebug"), logType: .debug)
            sdn_log(object: "Replaced Items: \(updates.changes.replaces)", category: Category.custom(categoryName: "CollectionViewDebug"), logType: .debug)
            sdn_log(object: "Moved Items: \(updates.changes.moves)", category: Category.custom(categoryName: "CollectionViewDebug"), logType: .debug)

            self.collectionView.reload(changesWithIndexPath: updates.changes,
                                   updateData: { [weak self] in

                                    sdn_log(object: "update data called", category: Category.custom(categoryName: "CollectionViewDebug"),logType: .debug)
                                    self?.sections = updates.sections

                                    let changedIndexPaths = updates.changes.inserts + updates.changes.deletes
                                    self?.updateLayoutCache(indexPaths: changedIndexPaths)
                                    self?.clearLayoutCache()

            }, completion: { [weak self] (completed) in

                sdn_log(object: "update complete", category: Category.custom(categoryName: "CollectionViewDebug"),logType: .debug)
                sdn_log(object: "lock released", category: Category.threadLock, logType: .debug)
                self?.collectionViewUpdateGroup.leave()
            })
        }.disposed(by: disposeBag)
    }
}

public extension UICollectionView {

    func reload<SectionType: DiffAwareSectionModelType>(
        changesWithIndexPath: SectionChangesWithIndexPath<SectionType>,
        updateData: () -> Void,
        completion: ((Bool) -> Void)? = nil) {

        performBatchUpdates({
            updateData()
            self.insideUpdate(changesWithIndexPath: changesWithIndexPath)

        }) { (completed) in

            sdn_log(object: "update complete", category: Category.custom(categoryName: "CollectionViewDebug"),logType: .debug)

            completion?(completed)
        }

        outsideUpdate(changesWithIndexPath: changesWithIndexPath)
    }

    // MARK: - Helper

    private func insideUpdate<SectionType: DiffAwareSectionModelType>(
        changesWithIndexPath: SectionChangesWithIndexPath<SectionType>) {

        changesWithIndexPath.sectionDeletes.executeIfPresent {
            deleteSections($0)
        }

        changesWithIndexPath.sectionInserts.executeIfPresent {
            insertSections($0)
        }

        changesWithIndexPath.deletes.executeIfPresent {
            deleteItems(at: $0)
        }

        changesWithIndexPath.inserts.executeIfPresent {
            insertItems(at: $0)
        }

        changesWithIndexPath.moves.executeIfPresent {
            $0.forEach { move in
                moveItem(at: move.from, to: move.to)
            }
        }
    }

    private func outsideUpdate<SectionType: DiffAwareSectionModelType>(
        changesWithIndexPath: SectionChangesWithIndexPath<SectionType>) {

        changesWithIndexPath.replaces.executeIfPresent {
            reloadItems(at: $0)
        }
    }
}
