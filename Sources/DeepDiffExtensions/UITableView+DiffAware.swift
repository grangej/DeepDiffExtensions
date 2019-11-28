import DeepDiff
import UIKit

public struct CollectionUpdates<SectionType: DiffAwareSectionModelType> {

    public let changes: SectionChangesWithIndexPath<SectionType>
    public let sections: [SectionType]
}

public protocol DiffAwareSectionModelType: DiffAware, Equatable where ItemType: DiffAware {
    associatedtype ItemType
    var items: [ItemType] { get }
}

public extension IndexSet {
  func executeIfPresent(_ closure: (IndexSet) -> Void) {
    if !isEmpty {
      closure(self)
    }
  }
}

public extension UITableView {

    /// Animate reload in a batch update
    ///
    /// - Parameters:
    ///   - changesWithIndexPath: The changes from diff
    ///   - insertionAnimation: The animation for insert rows
    ///   - deletionAnimation: The animation for delete rows
    ///   - replacementAnimation: The animation for reload rows
    ///   - updateData: Update your data source model
    ///   - completion: Called when operation completes
    func reload<SectionType: DiffAwareSectionModelType>(
        changesWithIndexPath: SectionChangesWithIndexPath<SectionType>,
        insertionAnimation: UITableView.RowAnimation = .automatic,
        deletionAnimation: UITableView.RowAnimation = .automatic,
        replacementAnimation: UITableView.RowAnimation = .automatic,
        sectionInsertionAnimation: UITableView.RowAnimation = .automatic,
        sectionDeletionAnimation: UITableView.RowAnimation = .automatic,
        updateData: () -> Void,
        completion: ((Bool) -> Void)? = nil) {

        unifiedPerformBatchUpdates({
            updateData()
            self.insideUpdate(
                changesWithIndexPath: changesWithIndexPath,
                insertionAnimation: insertionAnimation,
                deletionAnimation: deletionAnimation
            )
        }, completion: { finished in
            completion?(finished)
        })

        // reloadRows needs to be called outside the batch
        outsideUpdate(changesWithIndexPath: changesWithIndexPath, replacementAnimation: replacementAnimation)
    }

    // MARK: - Helper

    private func unifiedPerformBatchUpdates(
        _ updates: (() -> Void),
        completion: (@escaping (Bool) -> Void)) {

        if #available(iOS 11, tvOS 11, *) {
            performBatchUpdates(updates, completion: completion)
        } else {
            beginUpdates()
            updates()
            endUpdates()
            completion(true)
        }
    }

    private func insideUpdate<SectionType: DiffAwareSectionModelType>(
        changesWithIndexPath: SectionChangesWithIndexPath<SectionType>,
        insertionAnimation: UITableView.RowAnimation,
        deletionAnimation: UITableView.RowAnimation) {

        changesWithIndexPath.sectionDeletes.executeIfPresent {
            deleteSections($0, with: deletionAnimation)
        }

        changesWithIndexPath.sectionInserts.executeIfPresent {
            insertSections($0, with: deletionAnimation)
        }

        changesWithIndexPath.deletes.executeIfPresent {
            deleteRows(at: $0, with: deletionAnimation)
        }

        changesWithIndexPath.inserts.executeIfPresent {
            insertRows(at: $0, with: insertionAnimation)
        }

        changesWithIndexPath.moves.executeIfPresent {
            $0.forEach { move in
                moveRow(at: move.from, to: move.to)
            }
        }
    }

    private func outsideUpdate<SectionType: DiffAwareSectionModelType>(
        changesWithIndexPath: SectionChangesWithIndexPath<SectionType>,
        replacementAnimation: UITableView.RowAnimation) {

        changesWithIndexPath.replaces.executeIfPresent {
            reloadRows(at: $0, with: replacementAnimation)
        }
    }

    func convert<T>(changes: [Int: [Change<T>]]) -> ChangeWithIndexPath {

        var allInserts: [IndexPath] = []
        var allDeletes: [IndexPath] = []
        var allReplaces: [IndexPath] = []
        var allMoves: [(from: IndexPath, to: IndexPath)] = []

        for section in changes.keys {

            if let items = changes[section] {

                let inserts = items.compactMap({ $0.insert }).map({ $0.index.toIndexPath(section: section) })
                let deletes = items.compactMap({ $0.delete }).map({ $0.index.toIndexPath(section: section) })
                let replaces = items.compactMap({ $0.replace }).map({ $0.index.toIndexPath(section: section) })
                let moves = items.compactMap({ $0.move }).map({
                    (
                        from: $0.fromIndex.toIndexPath(section: section),
                        to: $0.toIndex.toIndexPath(section: section)
                    )
                })

                allInserts.append(contentsOf: inserts)
                allDeletes.append(contentsOf: deletes)
                allReplaces.append(contentsOf: replaces)
                allMoves.append(contentsOf: moves)
            }
        }

        return ChangeWithIndexPath(inserts: allInserts, deletes: allDeletes, replaces: allReplaces, moves: allMoves)
    }
}

public struct ChangeWithIndexSet {

    public let inserts: IndexSet
    public let deletes: IndexSet
    public let replaces: IndexSet
    public let moves: [(from: Int, to: Int)]
}

public extension UICollectionView {

    func convert<T>(changes: [Change<T>]) -> ChangeWithIndexSet {

        let inserts = IndexSet(changes.compactMap({ $0.insert }).map({ $0.index }))
        let deletes = IndexSet(changes.compactMap({ $0.delete }).map({ $0.index }))
        let replaces = IndexSet(changes.compactMap({ $0.replace }).map({ $0.index }))
        let moves = changes.compactMap({ $0.move }).map({
            (
                from: $0.fromIndex,
                to: $0.toIndex
            )
        })
        return ChangeWithIndexSet(inserts: inserts, deletes: deletes, replaces: replaces, moves: moves)
    }
}
