//
//  LogHabitCollectionViewController.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 09/09/2022.
//

import UIKit

private let reuseIdentifier = "Cell"

class LogHabitCollectionViewController: HabitCollectionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    
    
    // MARK: - Methods
    override func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, environment) -> NSCollectionLayoutSection? in
            if sectionIndex == 0 && self.model.favoriteHabits.count > 0 {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.45), heightDimension: .fractionalHeight(1)))
                item.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
                
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(100)), subitem: item, count: 2)
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
                
                return section
            } else {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
                
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)), subitem: item, count: 2)
                group.interItemSpacing = .fixed(8)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
                
                let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36)), elementKind: SectionHeader.kind.identifier, alignment: .top)
                sectionHeader.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: nil, trailing: nil, bottom: .fixed(40))
                sectionHeader.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
                section.boundarySupplementaryItems = [sectionHeader]
                section.interGroupSpacing = 10
                
                return section
                }
            }
    }
    
    
    override func configureCell(_ cell: UICollectionViewListCell, withItem itemIdentifier: HabitCollectionViewController.ViewModel.Item) {
        cell.configurationUpdateHandler = { cell, state in
            var content = UIListContentConfiguration.cell()
            content.text = itemIdentifier.name
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 11, leading: 8, bottom: 11, trailing: 8)
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            
            var backGroundConfiguration = UIBackgroundConfiguration.clear()
            if Settings.shared.favoriteHabits.contains(itemIdentifier) {
                backGroundConfiguration.backgroundColor = favoriteHabitColor
            } else {
                backGroundConfiguration.backgroundColor = .systemGray6
            }
            
            if state.isHighlighted {
                backGroundConfiguration.backgroundColorTransformer = .init { $0.withAlphaComponent(0.3) }
            }
            backGroundConfiguration.cornerRadius = 8
            cell.backgroundConfiguration = backGroundConfiguration
        }
        
        cell.layer.shadowRadius = 3
        cell.layer.shadowColor = UIColor.systemGray3.cgColor
        cell.layer.shadowOpacity = 1
        cell.layer.masksToBounds = false
    }
    
    
    
    // MARK: - Delegates
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        let loggedHabbit = LoggedHabiit(userID: Settings.shared.currentUser.id, habitName: item.name, timestamp: Date())
        
        Task {
            try? await LogHabbitRequest(loggedHabbit: loggedHabbit).send()
        }
    }
}
