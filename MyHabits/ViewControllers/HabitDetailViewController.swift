//
//  HabitDetailViewController.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 09/09/2022.
//

import UIKit

class HabitDetailViewController: UIViewController {
    // MARK: - Properties
    var habit: Habit!
    
    var habitStatisticsRequestTask: Task<Void, Never>? = nil
    deinit { habitStatisticsRequestTask?.cancel() }
    
    var updateTimer: Timer?
    
    
    
    // MARK: - Outlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    
    
    // MARK: - Lifecycle
    init?(coder: NSCoder, habit: Habit) {
        self.habit = habit
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nameLabel.text = habit.name
        categoryLabel.text = habit.category.name
        infoLabel.text = habit.info
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
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
        habitStatisticsRequestTask?.cancel()
        habitStatisticsRequestTask = Task {
            if let statistics = try? await HabitStatisticRequest(habitNames: [habit.name]).send(),
               statistics.count > 0 {
                self.model.habitStatistics = statistics[0]
            } else {
                self.model.habitStatistics = nil
            }
            
            self.updateCollectionView()
        
            habitStatisticsRequestTask = nil
        }
    }
    
    
    
    func updateCollectionView() {
        let items = (self.model.habitStatistics?.userCounts.map({ ViewModel.Item.single($0) }) ?? []).sorted(by: > )
        
        dataSource.applySnapshotUsing(sectionIDs: [.remaining], itemsBySection: [.remaining: items])
    }
    
    
    
    func createDataSource() -> DataSourceType {
        return DataSourceType(collectionView: collectionView) { collectionView, indexPath, grouping -> UICollectionViewCell in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UserCount", for: indexPath)
            
            var content = UIListContentConfiguration.subtitleCell()
            content.prefersSideBySideTextAndSecondaryText = true
            switch grouping {
            case .single(let userStat):
                content.text = userStat.user.name
                content.secondaryText = "\(userStat.count)"
                content.textProperties.font = .preferredFont(forTextStyle: .headline)
                content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            default:
                break
            }
            
            cell.contentConfiguration = content
            
            return cell
        }
    }
    
    
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), subitem: item, count: 1)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    
    
    // MARK: - ViewModel
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    var dataSource: DataSourceType!
    var model = Model()
    
    enum ViewModel {
        enum Section: Hashable {
            case leaders(count: Int)
            case remaining
        }
        
        enum Item: Hashable, Comparable {
            case single(_ stat: UserCount)
            case multiple(_ stat: [UserCount])
            
            static func < (_ lhs: Item, _ rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.single(let lCount), .single(let rCount)):
                    return lCount.count < rCount.count
                case (.multiple(let lCounts), .multiple(let rCounts)):
                    return lCounts.first!.count < rCounts.first!.count
                case (.single, .multiple):
                    return false
                case (.multiple, .single):
                    return true
                }
            }
        }
    }
    
    
    struct Model {
        var habitStatistics: HabitStatistics?
        var userCounts: [UserCount] {
            habitStatistics?.userCounts ?? []
        }
    }
    
}
