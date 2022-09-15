//
//  FollowedUserCollectionViewCell.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 13/09/2022.
//

import UIKit

class FollowedUserCollectionViewCell: UICollectionViewCell {
    @IBOutlet var primaryTextLabel: UILabel!
    @IBOutlet var secondaryTextLabel: UILabel!
    
    @IBOutlet var separatorLineView: UIView!
    @IBOutlet var separatorLineViewConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        separatorLineViewConstraint.constant = 1 / UITraitCollection.current.displayScale
    }
}
