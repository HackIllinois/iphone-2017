//
//  HILoginFlowController.swift
//  HackIllinois
//
//  Created by HackIllinois Team on 12/2/17.
//  Copyright © 2017 HackIllinois. All rights reserved.
//  This file is part of the Hackillinois iOS App.
//  The Hackillinois iOS App is open source software, released under the University of
//  Illinois/NCSA Open Source License. You should have received a copy of
//  this license in a file with the distribution.
//

import AuthenticationServices
import UIKit
import APIManager
import Lottie
import Keychain
import HIAPI

class HILoginFlowController: UIViewController {
    // MARK: - Properties
    let animationView = AnimationView(name: "intro")
    var shouldDisplayAnimationOnNextAppearance = true

    // MARK: Status Bar
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    var statusBarIsHidden = false
    override var prefersStatusBarHidden: Bool {
        return statusBarIsHidden
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return (\HIAppearance.preferredStatusBarStyle).value
    }

    // prevents the login session from going out of scope during presentation
    var loginSession: ASWebAuthenticationSession?

    // MARK: ViewControllers
    lazy var loginSelectionViewController = HILoginSelectionViewController(delegate: self)

    // MARK: - Init
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshForThemeChange), name: .themeDidChange, object: nil)
        refreshForThemeChange()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) should not be used")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Themeable
    @objc func refreshForThemeChange() {
        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - UIViewController
extension HILoginFlowController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor <- \.baseBackground
        addChild(loginSelectionViewController)
        loginSelectionViewController.view.frame = view.frame
        loginSelectionViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(loginSelectionViewController.view)
        loginSelectionViewController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if shouldDisplayAnimationOnNextAppearance {
            animationView.contentMode = .scaleAspectFill
            animationView.frame = view.frame
            animationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(animationView)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldDisplayAnimationOnNextAppearance {
            statusBarIsHidden = true
            setNeedsStatusBarAppearanceUpdate()

            animationView.play { _ in
                self.animationView.removeFromSuperview()
                self.statusBarIsHidden = false
                UIView.animate(withDuration: 0.25) { () -> Void in
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
            shouldDisplayAnimationOnNextAppearance = false
        }
    }
}

// MARK: - Login Flow
private extension HILoginFlowController {
    private func attemptOAuthLogin(buildingUser user: HIUser, sender: HIBaseViewController) {
        let loginURL = HIAPI.AuthService.oauthURL(provider: user.provider)
        loginSession = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: nil) { [weak self] (url, error) in
            if let url = url,
                let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                let queryItems = components.queryItems,
                let code = queryItems.first(where: { $0.name == "code" })?.value,
                code.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                var user = user
                user.oauthCode = code
                self?.exchangeOAuthCodeForAPIToken(buildingUser: user, sender: sender)
            } else if let error = error {
                if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    // do nothing
                } else {
                    self?.presentAuthenticationFailure(withError: error, sender: sender)
                }
            } else {
                let error = HIError.unknownAuthenticationError
                self?.presentAuthenticationFailure(withError: error, sender: sender)
            }
        }
        loginSession?.presentationContextProvider = self
        loginSession?.start()
    }

    private func exchangeOAuthCodeForAPIToken(buildingUser user: HIUser, sender: HIBaseViewController) {
        HIAPI.AuthService.getAPIToken(provider: user.provider, code: user.oauthCode)
        .onCompletion { [weak self] result in
            do {
                let (apiToken, _) = try result.get()
                var user = user
                user.token = apiToken.token
                self?.populateUserData(buildingUser: user, sender: sender)
            } catch {
                self?.presentAuthenticationFailure(withError: error, sender: sender)
            }
        }
        .launch()
    }

    private func populateUserData(buildingUser user: HIUser, sender: HIBaseViewController) {
        subscribeUserToRelevantTopics(buildingUser: user, sender: sender)
        HIAPI.UserService.getUser()
        .onCompletion { [weak self] result in
            do {
                let (apiUser, _) = try result.get()
                var user = user
                user.id = apiUser.id
                user.username = apiUser.username
                user.firstName = apiUser.firstName
                user.lastName = apiUser.lastName
                user.email = apiUser.email
                self?.populateRoleData(buildingUser: user, sender: sender)
            } catch {
                self?.presentAuthenticationFailure(withError: error, sender: sender)
            }
        }
        .authorize(with: user)
        .launch()
    }

    private func subscribeUserToRelevantTopics(buildingUser user: HIUser, sender: HIBaseViewController) {
        HIAPI.AnnouncementService.updateSubscriptions()
        .authorize(with: user)
        .launch()
    }

    private func populateRoleData(buildingUser user: HIUser, sender: HIBaseViewController) {
        HIAPI.AuthService.getRoles()
        .onCompletion { [weak self] result in
            do {
                let (apiRolesContainer, _) = try result.get()
                var user = user
                user.roles = apiRolesContainer.roles
                if user.roles.contains(.applicant) {
                    self?.populateRegistrationData(buildingUser: user, sender: sender)
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .loginUser, object: nil, userInfo: ["user": user])
                    }
                }
            } catch {
                self?.presentAuthenticationFailure(withError: error, sender: sender)
            }
        }
        .authorize(with: user)
        .launch()
    }

    private func populateRegistrationData(buildingUser user: HIUser, sender: HIBaseViewController) {
        HIAPI.RegistrationService.getAttendee()
        .onCompletion { [weak self] result in
            do {
                let (apiAttendeeContainer, _) = try result.get()
                var user = user
                user.attendee = apiAttendeeContainer.attendee
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .loginUser, object: nil, userInfo: ["user": user])
                }
            } catch {
                self?.presentAuthenticationFailure(withError: error, sender: sender)
            }
        }
        .authorize(with: user)
        .launch()
    }

    private func presentAuthenticationFailure(withError error: Error, sender: HIBaseViewController) {
        DispatchQueue.main.async {
            sender.presentErrorController(title: "Authentication Failed", message: String(describing: error), dismissParentOnCompletion: false)
        }
    }
}

// MARK: - HILoginSelectionViewControllerDelegate
extension HILoginFlowController: HILoginSelectionViewControllerDelegate {
    func loginSelectionViewController(_ loginSelectionViewController: HILoginSelectionViewController,
                                      didMakeLoginSelection selection: HIAPI.AuthService.OAuthProvider) {
        let user = HIUser(provider: selection)
        attemptOAuthLogin(buildingUser: user, sender: loginSelectionViewController)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension HILoginFlowController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window ?? ASPresentationAnchor()
    }
}
