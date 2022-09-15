//
//  HabitCollectionViewController.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 09/09/2022.
//

import UIKit

let favoriteHabitColor = UIColor(hue: 0.15, saturation: 1, brightness: 0.9, alpha: 1)

class HabitCollectionViewController: UICollectionViewController {
    // MARK: - Properies
    var habitRequestTask: Task<Void, Never>? = nil
    deinit { habitRequestTask?.cancel() }
    
    enum SectionHeader: String {
        case kind = "SectionHeader"
        case reuse = "HeaderView"
        
        var identifier: String {
            return rawValue
        }
    }
    
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier)
        
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }
    
    
    
    // MARK: - Methods
    func update() {
        habitRequestTask?.cancel()
        habitRequestTask = Task {
            if let habits = try? await HabitRequest().send() {
                self.model.habitsByName = habits
            } else {
                self.model.habitsByName = [:]
            }
            self.updateCollectionView()
            
            habitRequestTask = nil
        }
    }
    
    
    
    func updateCollectionView() {
        var itemsBySection = model.habitsByName.values.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, habit in
            let item = habit
            let section: ViewModel.Section
            if model.favoriteHabits.contains(habit) {
                section = .favorites
            } else {
                section = .category(habit.category)
            }
            partial[section, default: []].append(item)
        }
        
        let sectionIDs = itemsBySection.keys.sorted()
        itemsBySection = itemsBySection.mapValues({ $0.sorted() })
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
     func configureCell(_ cell: UICollectionViewListCell, withItem itemIdentifier: ViewModel.Item) {
        var content = cell.defaultContentConfiguration()
        content.text = itemIdentifier.name
        cell.contentConfiguration = content
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Habit", for: indexPath) as! UICollectionViewListCell
            
            self.configureCell(cell, withItem: itemIdentifier)
            
            return cell
        }
        
        
        dataSource.supplementaryViewProvider = { (collectionView, kind, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier, for: indexPath) as! NamedSectionHeaderView
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            
            switch section {
            case .favorites:
                header.nameLabel.text = "Favorites"
            case .category(let category):
                header.nameLabel.text = category.name
            }
            
            header.backgroundColor = section.sectionColor
            
            return header
        }
        
        return dataSource
    }
    
    
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), subitem: item, count: 1)
        
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36)), elementKind: SectionHeader.kind.identifier, alignment: .top)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        section.boundarySupplementaryItems = [sectionHeader]
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    

    
    @IBSegueAction func showHabitsDetail(_ coder: NSCoder, sender: Any?) -> HabitDetailViewController? {
        guard let cell = sender,
              let indexPath = collectionView.indexPath(for: cell as! UICollectionViewCell),
              let item = dataSource.itemIdentifier(for: indexPath)
        else {
            return nil
        }
        
        return HabitDetailViewController(coder: coder, habit: item)
    }
    
    
    
    // MARK: - CollectionView Delegates
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let item = self.dataSource.itemIdentifier(for: indexPath)!
            
            let favoriteToggle = UIAction(title: self.model.favoriteHabits.contains(item) ? "Unfavorite" : "Favorite") { action in
                Settings.shared.toggleFavorites(item)
                self.updateCollectionView()
            }
            
            return UIMenu(title: "", subtitle: nil, image: nil, identifier: nil, options: [], children: [favoriteToggle])
        }
        
        return config
    }
    
    
    
    // MARK: - ViewModel
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    var dataSource: DataSourceType!
    var model = Model()
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case favorites
            case category(_ category: Category)
            
            var sectionColor: UIColor {
                switch self {
                case .favorites:
                    return favoriteHabitColor
                case .category(let category):
                    return category.color.uiColor
                }
            }
            
            static func < (lhs: HabitCollectionViewController.ViewModel.Section, rhs: HabitCollectionViewController.ViewModel.Section) -> Bool {
                switch (lhs, rhs) {
                case (.category(let l), .category(let r)):
                    return l.name < r.name
                case (.favorites, _):
                    return true
                case (_, .favorites):
                    return false
                }
            }
        
        }
        
        typealias Item = Habit
    }
    
    struct Model {
        var habitsByName = [String: Habit]()
        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }
    }
}



