//
//  PasscodeLockViewController.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit

open class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate {
    
    public enum LockState {
        case enterPasscode
        case enterOptionalPasscode
        case setPasscode
        case changePasscode
        case removePasscode
        
        func getState() -> PasscodeLockStateType {
            
            switch self {
            case .enterPasscode: return EnterPasscodeState()
            case .enterOptionalPasscode: return EnterOptionalPasscodeState()
            case .setPasscode: return SetPasscodeState()
            case .changePasscode: return ChangePasscodeState()
            case .removePasscode: return EnterPasscodeState(allowCancellation: true)
            }
        }
    }
    
    @IBOutlet open weak var titleLabel: UILabel?
    @IBOutlet open weak var descriptionLabel: UILabel?
    @IBOutlet open var placeholders: [PasscodeSignPlaceholderView] = [PasscodeSignPlaceholderView]()
    @IBOutlet open weak var cancelButton: UIButton?
    @IBOutlet open weak var deleteSignButton: UIButton?
    @IBOutlet open weak var touchIDButton: UIButton?
    @IBOutlet open weak var placeholdersX: NSLayoutConstraint?
    
    open var successCallback: ((_ lock: PasscodeLockType) -> Void)?
    open var dismissCompletionCallback: (()->Void)?
    open var cancelCompletionCallback: (()->Void)?
    open var wrongPasswordCallback: ((_ attemptNo: Int) -> Void)?
    open var tooManyAttemptsCallback: ((_ attemptNo: Int)->Void)?
    open var animateOnDismiss: Bool
    open var notificationCenter: NotificationCenter?
    
    open var overrideTitleText: String? = nil
    open var overrideDescriptionText: String? = nil

    internal let passcodeConfiguration: PasscodeLockConfigurationType
    internal var passcodeLock: PasscodeLockType
    internal var isPlaceholdersAnimationCompleted = true
    internal var extraCallbacks = false
    
    fileprivate var shouldTryToAuthenticateWithBiometrics = true
    
    // MARK: - Initializers
    
    public init(state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true, nibName: String = "PasscodeLockView", bundle: Bundle? = nil) {
        
        self.animateOnDismiss = animateOnDismiss
        
        passcodeConfiguration = configuration
        passcodeLock = PasscodeLock(state: state, configuration: configuration)
        
        let bundleToUse = bundle ?? bundleForResource(nibName, ofType: "nib")
        
        super.init(nibName: nibName, bundle: bundleToUse)
        
        passcodeLock.delegate = self
        notificationCenter = NotificationCenter.default
    }

    public convenience init(state: LockState, configuration: PasscodeLockConfigurationType, darkUI: Bool = false, animateOnDismiss: Bool = true) {

        if ( darkUI ) {
            
            self.init(state: state.getState(), configuration: configuration, animateOnDismiss: animateOnDismiss, nibName: "DarkPasscodeLockView", bundle: nil)
            
        } else {
            
            self.init(state: state.getState(), configuration: configuration, animateOnDismiss: animateOnDismiss)
        }
        
        self.extraCallbacks = ( state == .enterPasscode || state == .enterOptionalPasscode )
        
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
        clearEvents()
    }
    
    // MARK: - View
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        deleteSignButton?.isEnabled = false
        
        setupEvents()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        EnterPasscodeState.incorrectPasscodeAttempts = 0
        updatePasscodeView()
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldTryToAuthenticateWithBiometrics && passcodeConfiguration.shouldRequestTouchIDImmediately {

            authenticateWithBiometrics()
        }
    }

    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updatePasscodeView()
    }
    
    internal func updatePasscodeView() {
        
        titleLabel?.text = ( overrideTitleText != nil ? overrideTitleText! : passcodeLock.state.title )
        descriptionLabel?.text = ( overrideDescriptionText != nil ? overrideDescriptionText! : passcodeLock.state.description )
        cancelButton?.isHidden = !passcodeLock.state.isCancellableAction
        touchIDButton?.isHidden = !passcodeLock.isTouchIDAllowed || passcodeLock.configuration.shouldDisableTouchIDButton
    }
    
    // MARK: - Events
    
    fileprivate func setupEvents() {
        
        notificationCenter?.addObserver(self, selector: #selector(PasscodeLockViewController.appWillEnterForegroundHandler(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.addObserver(self, selector: #selector(PasscodeLockViewController.appDidEnterBackgroundHandler(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    fileprivate func clearEvents() {
        
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    @objc open func appWillEnterForegroundHandler(_ notification: Notification) {
        
        shouldTryToAuthenticateWithBiometrics = true

        if passcodeConfiguration.shouldRequestTouchIDImmediately {
            authenticateWithBiometrics()
        }
    }
    
    @objc open func appDidEnterBackgroundHandler(_ notification: Notification) {
        
        shouldTryToAuthenticateWithBiometrics = false
    }
    
    // MARK: - Actions
    
    @IBAction func passcodeSignButtonTap(_ sender: PasscodeSignButton) {
        
        guard isPlaceholdersAnimationCompleted else { return }
        
        passcodeLock.addSign(sender.passcodeSign)
    }
    
    @IBAction func cancelButtonTap(_ sender: UIButton) {
        
        dismissPasscodeLock(passcodeLock, completionHandler: { [weak self] in
            self?.cancelCompletionCallback?()
        })
    }
    
    @IBAction func deleteSignButtonTap(_ sender: UIButton) {
        
        passcodeLock.removeSign()
    }
    
    @IBAction func touchIDButtonTap(_ sender: UIButton) {
        
        passcodeLock.authenticateWithBiometrics()
    }
    
    open func authenticateWithBiometrics() {
        
        guard passcodeConfiguration.repository.hasPasscode else { return }

        if passcodeLock.isTouchIDAllowed {
            
            passcodeLock.authenticateWithBiometrics()
        }
    }
    
    internal func dismissPasscodeLock(_ lock: PasscodeLockType, completionHandler: (() -> Void)? = nil) {
        
        // if presented as modal
        if presentingViewController?.presentedViewController == self {

            dismiss(animated: animateOnDismiss, completion: { [weak self] in
                completionHandler?()

                self?.dismissCompletionCallback?()
            })
            
            return
            
            // if pushed in a navigation controller
        } else if navigationController != nil {

            navigationController?.popViewController(animated: animateOnDismiss)
        }
        
        completionHandler?()

        dismissCompletionCallback?()        
    }
    
    // MARK: - Animations
    
    internal func animateWrongPassword() {
        
        deleteSignButton?.isEnabled = false
        isPlaceholdersAnimationCompleted = false
        
        animatePlaceholders(placeholders, toState: .error)
        
        placeholdersX?.constant = -40
        view.layoutIfNeeded()
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.2,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                
                self.placeholdersX?.constant = 0
                self.view.layoutIfNeeded()
        },
            completion: { completed in
                
                self.isPlaceholdersAnimationCompleted = true
                self.animatePlaceholders(self.placeholders, toState: .inactive)
        })
    }
    
    internal func animatePlaceholders(_ placeholders: [PasscodeSignPlaceholderView], toState state: PasscodeSignPlaceholderView.State) {
        
        for placeholder in placeholders {
            
            placeholder.animateState(state)
        }
    }
    
    fileprivate func animatePlacehodlerAtIndex(_ index: Int, toState state: PasscodeSignPlaceholderView.State) {
        
        guard index < placeholders.count && index >= 0 else { return }
        
        placeholders[index].animateState(state)
    }

    // MARK: - PasscodeLockDelegate
    
    open func passcodeLockDidSucceed(_ lock: PasscodeLockType) {
        
        deleteSignButton?.isEnabled = true
        animatePlaceholders(placeholders, toState: .inactive)
        dismissPasscodeLock(lock, completionHandler: { [weak self] in
            self?.successCallback?(lock)
        })
    }
    
    open func passcodeLockDidFail(_ lock: PasscodeLockType) {
        
        animateWrongPassword()
        
        if ( self.extraCallbacks ) {
            let attemptNo = EnterPasscodeState.incorrectPasscodeAttempts + 1
            let maxAttempts = lock.configuration.maximumInccorectPasscodeAttempts
            let shouldDissmissOnTooManyAttempts = lock.configuration.shouldDismissOnTooManyAttempts && lock.state.isCancellableAction
            
            if (( maxAttempts >= 0) && ( attemptNo >= maxAttempts )) {
                if ( shouldDissmissOnTooManyAttempts ) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {

                        self.dismissPasscodeLock(lock, completionHandler: { [weak self] in
                            self?.tooManyAttemptsCallback?(attemptNo)
                        })
                    })			
                } else {
                    self.tooManyAttemptsCallback?(attemptNo)
                }
            } else {
                self.wrongPasswordCallback?(attemptNo)
            }
        }
    }
    
    open func passcodeLockDidChangeState(_ lock: PasscodeLockType) {
        
        updatePasscodeView()
        animatePlaceholders(placeholders, toState: .inactive)
        deleteSignButton?.isEnabled = false
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, addedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .active)
        deleteSignButton?.isEnabled = true
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, removedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .inactive)
        
        if index == 0 {
            
            deleteSignButton?.isEnabled = false
        }
    }
}
