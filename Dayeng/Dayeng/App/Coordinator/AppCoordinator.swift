//
//  AppCoordinator.swift
//  Dayeng
//
//  Created by 배남석 on 2023/02/09.
//

import UIKit
import RxSwift

protocol AppCoordinatorProtocol: Coordinator {
    func showSplashViewController()
    func showLoginViewController()
    func showMainViewController()
}

final class AppCoordinator: AppCoordinatorProtocol {
    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    weak var delegate: CoordinatorDelegate?
    var disposeBag = DisposeBag()
    
    required init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        showSplashViewController()
    }
    
    func showSplashViewController() {
        let firestoreService = DefaultFirestoreDatabaseService()
        let useCase = DefaultSplashUseCase(
            userRepository: DefaultUserRepository(firestoreService: firestoreService),
            questionRepository: DefaultQuestionRepository(firestoreService: firestoreService),
            appleLoginService: DefaultAppleLoginService(),
            kakaoLoginService: DefaultKakaoLoginService()
        )
        let viewModel = SplashViewModel(useCase: useCase)
        let viewController = SplashViewController(viewModel: viewModel)
        
        viewModel.loginStatus
            .subscribe(onNext: { [weak self] loginResult in
                guard let self else { return }
                DispatchQueue.main.async {
                    if loginResult {
                        self.showMainViewController()
                    } else {
                        self.showLoginViewController()
                    }
                }
            }, onDisposed: {
                DispatchQueue.main.async {
                    (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?
                        .setNetworkMonitor()
                }
            })
            .disposed(by: disposeBag)
        
        navigationController.viewControllers = [viewController]
    }
    
    func showLoginViewController() {
        let firestoreService = DefaultFirestoreDatabaseService()
        let userRepository = DefaultUserRepository(firestoreService: firestoreService)
        let authService = DefaultAuthService(
            firebaseAuthService: DefaultFirebaseAuthService(),
            appleLoginService: DefaultAppleLoginService(),
            kakaoLoginService: DefaultKakaoLoginService()
        )
        let useCase = DefaultLoginUseCase(
            userRepository: userRepository,
            authService: authService
        )
        let viewModel = LoginViewModel(useCase: useCase)
        let viewController = LoginViewController(viewModel: viewModel)
        
        viewModel.loginResult
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                self.navigationController.viewControllers.last?.hideIndicator()
                self.showMainViewController()
            }, onError: { [weak self] error in
                guard let self else { return }
                let loginFailAlert = AlertMessageType.loginFail(error: error)
                self.navigationController.showAlert(
                    title: loginFailAlert.title,
                    message: loginFailAlert.message,
                    type: .oneButton,
                    rightActionHandler: { [weak self] in
                        guard let self else { return }
                        self.navigationController.viewControllers.last?.hideIndicator()
                        self.showLoginViewController()
                    }
                )
            })
            .disposed(by: disposeBag)
        
        (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?
            .changeRootViewController(navigationController, viewController)
    }
    
    func showAcceptFriendViewController(acceptFriendCode: String, acceptFriendName: String) {
        let firestoreService = DefaultFirestoreDatabaseService()
        let userRepository = DefaultUserRepository(firestoreService: firestoreService)
        let useCase = DefaultAcceptFriendUseCase(userRepository: userRepository)
        let viewModel = AcceptFriendViewModel(useCase: useCase, acceptFriendCode: acceptFriendCode)
        let viewController = AcceptFriendViewController(viewModel: viewModel, acceptFriendName: acceptFriendName)
        
        viewController.modalPresentationStyle = .fullScreen
        navigationController.present(viewController, animated: true)
    }
    
    func showMainViewController() {
        let coordinator = MainCoordinator(navigationController: navigationController)
        coordinator.delegate = self
        childCoordinators.append(coordinator)
        coordinator.start()
    }
}

extension AppCoordinator: CoordinatorDelegate {
    func didFinished(childCoordinator: Coordinator) {
        childCoordinators = childCoordinators.filter({ $0 !== childCoordinator })
        showLoginViewController()
    }
}
