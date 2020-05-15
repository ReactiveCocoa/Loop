import UIKit

final class ArrayCollectionViewDataSource<T>: NSObject, UICollectionViewDataSource {
    typealias CellFactory = (UICollectionView, IndexPath, T) -> UICollectionViewCell

    private(set) var items: [T] = []
    var cellFactory: CellFactory!

    func update(with items: [T]) {
        self.items = items
    }

    func item(atIndexPath indexPath: IndexPath) -> T {
        return items[indexPath.row]
    }

    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return cellFactory(collectionView, indexPath, item(atIndexPath: indexPath))
    }
}

