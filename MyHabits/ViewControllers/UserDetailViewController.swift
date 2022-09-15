//
//  UserDetailViewController.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 09/09/2022.
//

import UIKit

class UserDetailViewController: UIViewController {
    // MARK: - Properties
    var user: User!
    
    var imageRequestTask: Task<Void, Never>? = nil
    var userStaticticsRequestTask: Task<Void, Never>? = nil
    var leadingStatisticsRequestTask: Task<Void, Never>? = nil
    deinit {
        imageRequestTask?.cancel()
        userStaticticsRequestTask?.cancel()
        leadingStatisticsRequestTask?.cancel()
    }
    
    var updateTimer: Timer?
    
    
    
    enum SectionHeader: String {
        case kind = "SectionHeader"
        case reuse = "HeaderView"
        
        var identifier: String {
            return rawValue
        }
    }
    
    
    
    // MARK: - Outlets
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    
    
    // MARK: - Lifecycle
    init?(coder: NSCoder, user: User) {
        self.user = user
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder: hasn't been implemented")
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userNameLabel.text = user.name
        bioLabel.text = user.bio
        imageRequestTask = Task {
            if let image = try? await ImageRequest(imageID: user.id).send() {
                self.profileImageView.image = image
            }
            imageRequestTask = nil
        }
        
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier)
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        view.backgroundColor = user.color?.uiColor ?? .white
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.backgroundColor = .quaternarySystemFill
        tabBarController?.tabBar.scrollEdgeAppearance = tabBarAppearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.backgroundColor = .quaternarySystemFill
        navigationItem.scrollEdgeAppearance = navBarAppearance
        
        update()
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        update()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.update()
        })
    }
    
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    
    
    // MARK: - Methods
    func update() {
        userStaticticsRequestTask?.cancel()
        userStaticticsRequestTask = Task {
            if let userStats = try? await UserStatictiscRequest(userIDs: [user.id]).send(),
               userStats.count > 0 {
                self.model.userStats = userStats[0]
            } else {
                self.model.userStats = nil
            }
            
            self.updateCollectionView()
            
            userStaticticsRequestTask = nil
        }
        
        leadingStatisticsRequestTask?.cancel()
        leadingStatisticsRequestTask = Task {
            if let leadingStats = try? await HabitLeadStatisticRequest(userID: user.id).send() {
                self.model.leadingStats = leadingStats
            } else {
                self.model.leadingStats = nil
            }
            
            self.updateCollectionView()
            
            leadingStatisticsRequestTask = nil
        }
    }
    
    
    
    func updateCollectionView() {
        guard let userStatistics = self.model.userStats,
              let leadingStatistics = self.model.leadingStats else { return }
        
        var itemsBySection = userStatistics.habitCounts.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partialResult, habitCount in
            let section: ViewModel.Section
            
            if leadingStatistics.habitCounts.contains(habitCount) {
                section = .leading
            } else {
                section = .category(habitCount.habit.category)
            }
            
            partialResult[section, default: []].append(habitCount)
        }
        
        itemsBySection = itemsBySection.mapValues { $0.sorted() }
        
        let sectionIDs = itemsBySection.keys.sorted()
        
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, habitStat -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HabitCount", for: indexPath)
            
            var content = UIListContentConfiguration.subtitleCell()
            
            content.text = habitStat.habit.name
            content.secondaryText = "\(habitStat.count)"
            
            content.prefersSideBySideTextAndSecondaryText = true
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cell.contentConfiguration = content
            
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, category, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier, for: indexPath) as! NamedSectionHeaderView
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            
            switch section {
            case .leading:
                header.nameLabel.text = "Leading"
                header.backgroundColor = .systemYellow
            case .category(let category):
                header.nameLabel.text = category.name
                header.backgroundColor = section.sectionColor
            }
            
            return header
        }
        
        
        
        
        return dataSource
    }
    
    
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), subitem: item, count: 1)
        
        let sectionHeader = (NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36)), elementKind: SectionHeader.kind.identifier, alignment: .top))
        sectionHeader.pinToVisibleBounds = true
        
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [sectionHeader]
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    
    
    // MARK: - ViewModel
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case leading
            case category(_ category: Category)
            
            var sectionColor: UIColor {
                switch self {
                case .leading:
                    return .systemGray4
                case .category(let category):
                    return category.color.uiColor
                }
            }
            
            static func <(lhs: Section, rhs: Section) -> Bool {
                switch (lhs, rhs) {
                case (.leading, .category), (.leading, .leading):
                    return true
                case (.category, .leading):
                    return false
                case (category(let category1), category(let category2)):
                    return category1.name > category2.name
                }
            }
        }
        
        typealias Item = HabitCount
    }
    
    
    
    struct Model {
        var userStats: UserStatistics?
        var leadingStats: UserStatistics?
    }
    
    var dataSource: DataSourceType!
    var model = Model()
}
