import Foundation

public extension Int {

    func toIndexPath(section: Int) -> IndexPath {
        return IndexPath(item: self, section: section)
    }

    func indexPaths(_ page: Int, pageSize: Int, section: Int, indexPaths: Set<IndexPath>) -> Set<IndexPath> {

        var indexPaths = indexPaths

        for index in 0..<self {

            let row = index + (page * pageSize)
            let indexPath = IndexPath(row: row, section: section)
            indexPaths.insert(indexPath)
        }

        return indexPaths
    }
}
