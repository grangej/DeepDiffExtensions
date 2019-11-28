import Foundation
import DeepDiff

struct SectionChangesWithIndexPath<SectionType: DiffAwareSectionModelType> {

    public let sectionInserts: IndexSet
    public let sectionDeletes: IndexSet
    public let inserts: [IndexPath]
    public let deletes: [IndexPath]
    public let replaces: [IndexPath]
    public let moves: [(from: IndexPath, to: IndexPath)]

    public init(
        sectionInserts: IndexSet,
        sectionDeletes: IndexSet,
        inserts: [IndexPath],
        deletes: [IndexPath],
        replaces:[IndexPath],
        moves: [(from: IndexPath, to: IndexPath)]) {

        self.sectionInserts = sectionInserts
        self.sectionDeletes = sectionDeletes
        self.inserts = inserts
        self.deletes = deletes
        self.replaces = replaces
        self.moves = moves
    }


    /// Init with existing sections and updated sections
    /// *caution* this could be an expensive operation and should NOT be performed no the main thread
    /// - Parameter existingSections: existing sections before the update
    /// - Parameter updatedSections: updated sections after the update
    init(existingSections: [SectionType], updatedSections: [SectionType]) {

        let sectionChanges = diff(old: existingSections, new: updatedSections)

        var insertedSections = IndexSet(sectionChanges.compactMap({ $0.insert }).map({ $0.index }))
        var deletedSections = IndexSet(sectionChanges.compactMap({ $0.delete }).map({ $0.index }))

        let moves = sectionChanges.compactMap { $0.move }

        /// Treat moves as insert / delete operations to make row updates simpler
        for move in moves {

            insertedSections.insert(move.toIndex)
            deletedSections.insert(move.fromIndex)
        }

        var allInserts: [IndexPath] = []
        var allDeletes: [IndexPath] = []
        var allReplaces: [IndexPath] = []
        var allMoves: [(from: IndexPath, to: IndexPath)] = []

        for sectionIndex in 0..<updatedSections.count {

            guard !insertedSections.contains(sectionIndex) else { continue }

            guard existingSections.count > sectionIndex else { continue }

            guard let existingSectionIndex = (existingSections.firstIndex { (sectionModel) -> Bool in
                return sectionModel.diffId == updatedSections[sectionIndex].diffId
            }) else {

                continue
            }


            let existingItems = existingSections[existingSectionIndex].items
            let updatedItems = updatedSections[sectionIndex].items

            let rowChanges = diff(old: existingItems, new: updatedItems)

            let inserts = rowChanges.compactMap({ $0.insert }).map({ $0.index.toIndexPath(section: sectionIndex) })
            let deletes = rowChanges.compactMap({ $0.delete }).map({ $0.index.toIndexPath(section: sectionIndex) })
            let replaces = rowChanges.compactMap({ $0.replace }).map({ $0.index.toIndexPath(section: sectionIndex) })
            let moves = rowChanges.compactMap({ $0.move }).map({
                (
                    from: $0.fromIndex.toIndexPath(section: sectionIndex),
                    to: $0.toIndex.toIndexPath(section: sectionIndex)
                )
            })

            allInserts.append(contentsOf: inserts)
            allDeletes.append(contentsOf: deletes)
            allReplaces.append(contentsOf: replaces)
            allMoves.append(contentsOf: moves)

        }

        self.init(sectionInserts: insertedSections,
                  sectionDeletes: deletedSections,
                  inserts: allInserts,
                  deletes: allDeletes,
                  replaces: allReplaces,
                  moves: allMoves)
    }
}
