//
//  UserCollectionViewController.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 09/09/2022.
//

import UIKit

private let reuseIdentifier = "Cell"

class UserCollectionViewController: UICollectionViewController {
    // MARK: - Properies
    var userRequestTask: Task<Void, Never>? = nil
    deinit { userRequestTask?.cancel() }
    
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        update()
    }
    
    
    
    // MARK: - Methods
    func update() {
        userRequestTask?.cancel()
        userRequestTask = Task {
            if let users = try? await UserRequest().send() {
                self.model.userByID = users
            } else {
                self.model.userByID = [:]
            }
            
            self.updateCollectionView()
            userRequestTask = nil
        }
    }
    
    
    
    func updateCollectionView() {
        let users = model.userByID.values.sorted().reduce(into: [ViewModel.Item]()) { partial, user in
            partial.append(ViewModel.Item(user: user, isFollowed: model.followedUsers.contains(user)))
        }
        
        let itemsBySection = [0: users]
        
        dataSource.applySnapshotUsing(sectionIDs: [0], itemsBySection: itemsBySection)
    }
    
    
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "User", for: indexPath) as! UICollectionViewListCell
            
            
            var backgroundConfiguration = UIBackgroundConfiguration.clear()
            backgroundConfiguration.backgroundColor = itemIdentifier.user.color?.uiColor ?? UIColor.systemGray4
            backgroundConfiguration.cornerRadius = 8
            cell.backgroundConfiguration = backgroundConfiguration
            
            var content = cell.defaultContentConfiguration()
            content.text = itemIdentifier.user.name
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 11, leading: 8, bottom: 11, trailing: 8)
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            
            return cell
        }
        
        return dataSource
    }
    
    
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(0.45)), subitem: item, count: 2)
        group.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        group.interItemSpacing = .fixed(20)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    
    
    @IBSegueAction func showUserDetail(_ coder: NSCoder, sender: Any?) -> UserDetailViewController? {
        guard let cell = sender,
              let indexPath = collectionView.indexPath(for: cell as! UICollectionViewCell),
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        return UserDetailViewController(coder: coder, user: item.user)
    }
    
    
    
    
    // MARK: - CollectionView Delegates
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { (elements) in
            guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            
            let favoriteToggle = UIAction(title: item.isFollowed ? "Unfollow" : "Follow") { action in
                Settings.shared.toggleFollowed(user: item.user)
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
        typealias Section = Int
        
        struct Item: Hashable {
            let user: User
            let isFollowed: Bool
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(user)
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                return lhs.user == rhs.user
            }
        }
    }
    
    
    
    struct Model {
        var userByID = [String: User]()
        var followedUsers: [User] {
            return Array(userByID.filter{ Settings.shared.followedUserIDs.contains( $0.key )}.values)
        }
    }
}
