//
//  HIEventListViewController.swift
//  HackIllinois
//
//  Created by HackIllinois Team on 1/12/18.
//  Copyright © 2018 HackIllinois. All rights reserved.
//  This file is part of the Hackillinois iOS App.
//  The Hackillinois iOS App is open source software, released under the University of
//  Illinois/NCSA Open Source License. You should have received a copy of
//  this license in a file with the distribution.
//

import Foundation
import UIKit
import HIAPI
import APIManager
import os

class HIEventListViewController: HIBaseViewController {
    let eventDetailViewController = HIEventDetailViewController()
}

// MARK: - UITableView Setup
extension HIEventListViewController {
    override func setupTableView() {
        if let tableView = tableView {
            tableView.register(HIDateHeader.self, forHeaderFooterViewReuseIdentifier: HIDateHeader.identifier)
            tableView.register(HIEventCell.self, forCellReuseIdentifier: HIEventCell.identifier)
        }
        super.setupTableView()
    }
}

// MARK: - UITableViewDataSource
extension HIEventListViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HIEventCell.identifier, for: indexPath)
        if let cell = cell as? HIEventCell, let event = _fetchedResultsController?.object(at: indexPath) as? Event {
            cell <- event
            cell.delegate = self
            cell.indexPath = indexPath
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension HIEventListViewController {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let event = _fetchedResultsController?.object(at: indexPath) as? Event else {
            return CGFloat.leastNonzeroMagnitude
        }
        return HIEventCell.heightForCell(with: event)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        eventDetailViewController.event = _fetchedResultsController?.object(at: indexPath) as? Event
        navigationController?.pushViewController(eventDetailViewController, animated: true)
        super.tableView(tableView, didSelectRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let eventCell = tableView.cellForRow(at: indexPath) as? HIEventCell,
            let event = _fetchedResultsController?.object(at: indexPath) as? Event else { return nil }

        // Use favoritedButton button state instead of model state, essentially amounts to a debounce
        var menuActions = [UIMenuElement]()
        if eventCell.favoritedButton.isActive {
            let unfavorite = UIAction(
                title: "Unfavorite",
                image: .heartSlashFill) { _ in
                    self.unfavorite(event: event)
            }
            menuActions.append(unfavorite)
        } else {
            let favorite = UIAction(
                title: "Favorite",
                image: .heartFill) { _ in
                    self.favorite(event: event)
            }
            menuActions.append(favorite)
        }

        let menu = UIMenu(title: "", children: menuActions)
        let vc = eventDetailViewController
        vc.event = event
        let menuConfig = UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: { vc },
            actionProvider: { _ in menu })

        return menuConfig
    }
}

// MARK: - UIRefreshControl
extension HIEventListViewController {
    override func refresh(_ sender: UIRefreshControl) {
        super.refresh(sender)
        HIEventDataSource.refresh(completion: endRefreshing)
    }
}

// MARK: - HIEventCellDelegate
extension HIEventListViewController: HIEventCellDelegate {
    func eventCellDidSelectFavoriteButton(_ eventCell: HIEventCell) {
        guard let indexPath = eventCell.indexPath,
            let event = _fetchedResultsController?.object(at: indexPath) as? Event else { return }

        // Use favoritedButton button state instead of model state, essentially amounts to a debounce
        if eventCell.favoritedButton.isActive {
            unfavorite(event: event)
        } else {
            favorite(event: event)
        }
    }
}

// MARK: - Actions
extension HIEventListViewController {
    private func favorite(event: Event) {
        HIAPI.EventService.favoriteBy(id: event.id)
        .onCompletion { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    event.favorite = true
                    HILocalNotificationController.shared.scheduleNotification(for: event)
                }
            case .failure(let error):
                os_log(
                    "Favorite event by id failed with error: %s",
                    log: Logger.api,
                    type: .info,
                    String(describing: error)
                )
            }
        }
        .authorize(with: HIApplicationStateController.shared.user)
        .launch()
    }

    private func unfavorite(event: Event) {
        HIAPI.EventService.unfavoriteBy(id: event.id)
        .onCompletion { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    event.favorite = false
                    HILocalNotificationController.shared.unscheduleNotification(for: event)
                }
            case .failure(let error):
                os_log(
                    "Unfavorite event by id failed with error: %s",
                    log: Logger.api,
                    type: .info,
                    String(describing: error)
                )
            }
        }
        .authorize(with: HIApplicationStateController.shared.user)
        .launch()
    }
}
