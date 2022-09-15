//
//  HomeCollectionViewController.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 09/09/2022.
//

import UIKit


// MARK: - Extentions for UI polishing
enum SupplementaryItemType {
    case collectionSupplementaryView
    case layoutDecorationView
}



protocol SupplementaryItem {
    associatedtype ViewClass: UICollectionReusableView

    var itemType: SupplementaryItemType { get }

    var reuseIdentifier: String { get }
    var viewKind: String { get }
    var viewClass: ViewClass.Type { get }
}



extension SupplementaryItem {
    func register(on collectionView: UICollectionView) {
        switch itemType {
        case .collectionSupplementaryView:
            collectionView.register(viewClass.self, forSupplementaryViewOfKind: viewKind, withReuseIdentifier: reuseIdentifier)
        case .layoutDecorationView:
            collectionView.collectionViewLayout.register(viewClass.self, forDecorationViewOfKind: viewKind)
        }
    }
}



class SectionBackgroundView: UICollectionReusableView {
    override func didMoveToSuperview() {
        backgroundColor = .systemGray6
    }
}



// MARK: - HomeCollectionViewController Definition
class HomeCollectionViewController: UICollectionViewController {
    // MARK: - Properties
    var userRequestTask: Task<Void, Never>? = nil
    var habitRequestTask: Task<Void, Never>? = nil
    var combinedStatisticsRequestTask: Task<Void, Never>? = nil
    deinit {
        userRequestTask?.cancel()
        habitRequestTask?.cancel()
        combinedStatisticsRequestTask?.cancel()
    }

    var updateTimer: Timer?



    enum SupplementaryView: String, CaseIterable, SupplementaryItem {
        case leaderboardSectionHeader
        case leaderboardBackground
        case followedUsersSectionHeader

        var reuseIdentifier: String {
            return rawValue
        }

        var viewKind: String {
            return rawValue
        }

        var viewClass: UICollectionReusableView.Type {
            switch self {
            case .leaderboardBackground:
                return SectionBackgroundView.self
            default:
                return NamedSectionHeaderView.self
            }
        }

        var itemType: SupplementaryItemType {
            switch self {
            case .leaderboardBackground:
                return .layoutDecorationView
            default:
                return .collectionSupplementaryView
            }
        }
    }


    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        for supplementaryView in SupplementaryView.allCases {
            supplementaryView.register(on: collectionView)
        }

        userRequestTask = Task{
            if let users = try? await UserRequest().send() {
                self.model.usersByID = users
            }

            self.updateCollectionView()

            userRequestTask = nil
        }

        habitRequestTask = Task {
            if let habits = try? await HabitRequest().send() {
                self.model.habitsByName = habits
            }

            self.updateCollectionView()

            userRequestTask = nil
        }
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
        combinedStatisticsRequestTask?.cancel()
        combinedStatisticsRequestTask = Task {
            if let combinedStatistics = try? await CombinedStatisticsRequest().send(){
                self.model.userStatistics = combinedStatistics.userStatistics
                self.model.habitStatistics = combinedStatistics.habitStatistics
            } else {
                self.model.userStatistics = []
                self.model.habitStatistics = []
            }

            self.updateCollectionView()

            combinedStatisticsRequestTask = nil
        }
    }



    static let formatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    func ordinalString(from number: Int) -> String {
        return Self.formatter.string(from: NSNumber(integerLiteral: number + 1))!
    }

    

    func updateCollectionView() {
        var sectionIDs = [ViewModel.Section]()

        // Followed Habits Section
        let leaderBoardItems = model.habitStatistics.filter { statistics in
            return model.favoriteHabits.contains(where: { $0.name == statistics.habit.name })
        }.sorted { $0.habit.name < $1.habit.name }.reduce(into: [ViewModel.Item]()) {
            partialResult, statistics in
            // Rank the user counts from highest to lowest
            let rankedUserCounts = statistics.userCounts.sorted { $0.count > $1.count }

            // Find the index of the current user's count, keeping in mind that it won't exist if the user hasn't logged that habit yet
            let myCountIndex = rankedUserCounts.firstIndex(where: { $0.user.id == self.model.currentUser.id })

            func userRankingString(from userCount: UserCount) -> String {
                var name = userCount.user.name
                var ranking = ""
                if userCount.user.id == self.model.currentUser.id {
                    name = "You"
                    ranking = " (#\(ordinalString(from: myCountIndex!)))"
                }

                return "\(name) \(userCount.count)" + ranking
            }

            var leadingRanking: String?
            var secondaryRanking: String?

            // Examine the number of user counts for the statistic:
            switch rankedUserCounts.count {
                // If 0, set the leader label to "Nobody Yet!" and leave the secondary label `nil`
            case 0:
                leadingRanking = "Nobody yet!"
                // If 1, set the leader label to the only user and count
            case 1:
                leadingRanking = userRankingString(from: rankedUserCounts.first!)
                // Otherwise, do the following:
            default:
                // Set the leader label to the user count at index 0
                leadingRanking = userRankingString(from: rankedUserCounts[0])
                // Check whether the index of the current user's count exists and is not 0
                if let currentUserIndex = myCountIndex, currentUserIndex != rankedUserCounts.startIndex {
                    // If true, the user's count and ranking should be displayed in the secondary label
                    secondaryRanking = userRankingString(from: rankedUserCounts[currentUserIndex])
                } else {
                    // If false, the second-place user count should be displayed
                    secondaryRanking = userRankingString(from: rankedUserCounts[1])
                }
            }

            let leaderboardItem = ViewModel.Item.leaderboardHabit(name: statistics.habit.name, leadingUserRanking: leadingRanking, secondaryUserRanking: secondaryRanking)
            partialResult.append(leaderboardItem)
        }

        sectionIDs.append(.leaderboard)
        var itemsBySection = [ViewModel.Section.leaderboard: leaderBoardItems]


        // Followed Users Section
        var followedUserItems = [ViewModel.Item]()

        func loggedHabitNames(for user: User) -> Set<String> {
            var names = [String]()

            if let stats = model.userStatistics.first(where: { $0.user == user }) {
                names = stats.habitCounts.map { $0.habit.name }
            }
            return Set(names)
        }

        // Get the current user habits and extract the favorites
        let currentUserLoggedHabits = loggedHabitNames(for: self.model.currentUser)
        let favoriteLoggedHabits = Set(model.favoriteHabits.map({ $0.name })).intersection(currentUserLoggedHabits)

        // Loop through all the followed users
        for followedUser in self.model.followedUsers.sorted(by: { $0.name < $1.name }) {
            let message: String

            let followedUserLoggedHabits = loggedHabitNames(for: followedUser)

            // If the users have a habit in common:
            let commonLoggedHabits = followedUserLoggedHabits.intersection(currentUserLoggedHabits)

            if commonLoggedHabits.count > 0 {
                // Pick the habit to focus on
                let habitName: String
                let commonFavoriteLoggedHabits = favoriteLoggedHabits.intersection(commonLoggedHabits)

                if commonFavoriteLoggedHabits.count > 0 {
                    habitName = commonFavoriteLoggedHabits.sorted().first!
                } else {
                    habitName = commonLoggedHabits.sorted().first!
                }

                // Get the full statistics (all the user counts) for that habit
                let habitStats = self.model.habitStatistics.first(where: { $0.habit.name == habitName})!

                // Get the ranking for each user
                let rankedUserCounts = habitStats.userCounts.sorted(by: { $0.count > $1.count })
                let currentUserRanking = rankedUserCounts.firstIndex(where: { $0.user == self.model.currentUser })!
                let followedUserRanking = rankedUserCounts.firstIndex(where: { $0.user == followedUser })!

                // Construct the message depending on who's leading
                if currentUserRanking < followedUserRanking {
                    message = "Currently #\(ordinalString(from: followedUserRanking)), behind you (#\(ordinalString(from: currentUserRanking))) in \(habitName).\nSend them a friendly reminder!"
                } else if currentUserRanking > followedUserRanking {
                    message = "Currently #\(ordinalString(from: followedUserRanking)), ahead of you (#\(ordinalString(from: currentUserRanking))) in \(habitName).\nYou might catch up with a little extra effort!"
                } else {
                    message = "You're tied at \(ordinalString(from: followedUserRanking)) in \(habitName)! Now's your chance to pull ahead."
                }
            // Otherwise if follwed user has logged at least one habbit:
            } else if followedUserLoggedHabits.count > 0 {
                // Get an arbitrary habit name
                let habitName = followedUserLoggedHabits.sorted().first!
                // Get the full statistics (all the user counts) for that habit
                let habitStats = model.habitStatistics.first(where: { $0.habit.name == habitName })!

                // Get the users ranking for that habit
                let rankedUserCounts = habitStats.userCounts.sorted(by: { $0.count > $1.count })
                let followedUserRanking = rankedUserCounts.firstIndex(where: { $0.user == followedUser })!

                // Construct the message
                message = "Currently #\(ordinalString(from: followedUserRanking)), in \(habitName).\nMaybe you should give his habit a look."

            // Otherwise, this user hasn't done anything
            } else {
                message = "This user doesn't seem to have done musch yet. Check in to see if they need any help getting started."
            }

            followedUserItems.append(.followedUser(followedUser, message: message))
        }

        sectionIDs.append(.followedUsers)
        itemsBySection[.followedUsers] = followedUserItems

        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }



    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            switch item {
            case .leaderboardHabit(let name, let leadingUserRanking, let secondaryUserRanking):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LeaderboardHabit", for: indexPath) as! LeaderboardHabitCollectionViewCell
                cell.habitNameLabel.text = name
                cell.leaderLabel.text = leadingUserRanking
                cell.secondaryLabel.text = secondaryUserRanking
                
                cell.contentView.backgroundColor = favoriteHabitColor.withAlphaComponent(0.75)
                cell.contentView.layer.cornerRadius = 8
                cell.layer.shadowRadius = 3
                cell.layer.shadowColor = UIColor.systemGray3.cgColor
                cell.layer.shadowOffset = CGSize(width: 0, height: 0)
                cell.layer.shadowOpacity = 1
                cell.layer.masksToBounds = false
                
                return cell
            case .followedUser(let user, let message):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FollowedUser", for: indexPath) as! FollowedUserCollectionViewCell
                cell.primaryTextLabel.text = user.name
                cell.secondaryTextLabel.text = message
                
                if indexPath.item == collectionView.numberOfItems(inSection: indexPath.section) - 1 {
                    cell.separatorLineView.isHidden = true
                } else {
                    cell.separatorLineView.isHidden = false
                }
                
                return cell
            }
        }

        dataSource.supplementaryViewProvider = {
            (collectionView, kind, indexPath) in
            guard let elementKind = SupplementaryView(rawValue: kind) else { return nil }

            let view = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind.viewKind, withReuseIdentifier: elementKind.reuseIdentifier, for: indexPath)

            switch elementKind {
            case .leaderboardSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Leaderboard"
                header.nameLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
                header.alignLabelToTop()
                return header
            case .followedUsersSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Following"
                header.nameLabel.font = UIFont.preferredFont(forTextStyle: .title2)
                header.alignLabelToYCenter()
                return header
            default:
                return nil
            }
        }

        return dataSource
    }


    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, environment) -> NSCollectionLayoutSection? in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .leaderboard:
                let leaderboardItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3)))

                let leaderboardVerticalTrio = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.75), heightDimension: .fractionalWidth(0.75)), subitem: leaderboardItem, count: 3)
                leaderboardVerticalTrio.interItemSpacing = .fixed(10)

                let leaderboardSection = NSCollectionLayoutSection(group: leaderboardVerticalTrio)

                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)), elementKind: SupplementaryView.leaderboardSectionHeader.viewKind, alignment: .top)

                let background = NSCollectionLayoutDecorationItem.background(elementKind: SupplementaryView.leaderboardBackground.viewKind)

                leaderboardSection.boundarySupplementaryItems = [header]
                leaderboardSection.decorationItems = [background]
                leaderboardSection.supplementariesFollowContentInsets = false

                leaderboardSection.interGroupSpacing = 20

                leaderboardSection.orthogonalScrollingBehavior = .continuous
                leaderboardSection.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 20, trailing: 20)

                return leaderboardSection
            case .followedUsers:
                let followedUserItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100)))

                let followedUserGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100)), subitem: followedUserItem, count: 1)

                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(60)), elementKind: SupplementaryView.followedUsersSectionHeader.viewKind, alignment: .top)

                let followedUserSection = NSCollectionLayoutSection(group: followedUserGroup)

                followedUserSection.boundarySupplementaryItems = [header]

                return followedUserSection
            }
        }

        return layout
    }



    // MARK: - ViewModel
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>

    enum ViewModel {
        enum Section: Hashable {
            case leaderboard
            case followedUsers
        }

        enum Item: Hashable {
            case leaderboardHabit(name: String, leadingUserRanking: String?, secondaryUserRanking: String?)
            case followedUser(_ user: User, message: String)
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .leaderboardHabit(let name, _, _):
                    hasher.combine(name)
                case .followedUser(let User, _):
                    hasher.combine(User)
                }
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.leaderboardHabit(let lName, _, _), .leaderboardHabit(let rName, _, _)):
                    return lName == rName
                case (.followedUser(let lUser, _), .followedUser(let rUser, _)):
                    return lUser == rUser
                default:
                    return false
                }
            }
        }
    }


    struct Model {
        var usersByID = [String: User]()
        var habitsByName = [String: Habit]()
        var habitStatistics = [HabitStatistics]()
        var userStatistics = [UserStatistics]()

        var currentUser: User {
            return Settings.shared.currentUser
        }

        var users: [User] {
            return Array(usersByID.values)
        }

        var habits: [Habit] {
            return Array(habitsByName.values)
        }

        var followedUsers: [User] {
            return Array(usersByID.filter { Settings.shared.followedUserIDs.contains($0.key) }.values)
        }

        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }

        var nonFavoriteHabits: [Habit] {
            return habits.filter { !favoriteHabits.contains($0) }
        }
    }

    var model = Model()
    var dataSource: DataSourceType!
}
