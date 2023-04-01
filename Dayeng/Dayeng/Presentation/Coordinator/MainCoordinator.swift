//
//  MainCoordinator.swift
//  Dayeng
//
//  Created by 배남석 on 2023/02/10.
//

import UIKit
import RxSwift
import RxRelay

protocol MainCoordinatorProtocol: Coordinator {
    func showMainViewController()
}

final class MainCoordinator: MainCoordinatorProtocol {
    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    var delegate: CoordinatorDelegate?
    var disposeBag = DisposeBag()
    
    required init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        showMainViewController()
    }
    
    func showMainViewController() {
        let firestoreService = DefaultFirestoreDatabaseService()
        let userRepository = DefaultUserRepository(firestoreService: firestoreService)
        let useCase = DefaultMainUseCase(userRepository: userRepository)
        let viewModel = MainViewModel(useCase: useCase)
        let viewController = MainViewController(viewModel: viewModel)
        viewModel.friendButtonDidTapped
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                self.showFriendViewController()
            })
            .disposed(by: disposeBag)
        viewModel.settingButtonDidTapped
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                self.showSettingViewController()
            })
            .disposed(by: disposeBag)
        viewModel.calendarButtonDidTapped
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                self.showCalendarViewController(ownerType: .me)
            })
            .disposed(by: disposeBag)
        viewModel.editButtonDidTapped
            .subscribe(onNext: { [weak self] index in
                guard let self else { return }
                self.showEditViewController(index: index)
            })
            .disposed(by: disposeBag)
        
        (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?
            .changeRootViewController(navigationController, viewController)
    }
    
    func showCalendarViewController(ownerType: OwnerType) {
        let viewModel = CalendarViewModel()
        let viewController = CalendarViewController(ownerType: ownerType,
                                                    viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }
    
    func showFriendViewController() {
        let coordinator = FriendCoordinator(navigationController: navigationController)
        childCoordinators.append(coordinator)
        coordinator.start()
    }
    
    func showSettingViewController() {
        let coordinator = SettingCoordinator(navigationController: navigationController)
        childCoordinators.append(coordinator)
        coordinator.start()
    }
    
    func showEditViewController(index: Int) {
        let firestoreService = DefaultFirestoreDatabaseService()
        let userRepository = DefaultUserRepository(firestoreService: firestoreService)
        let useCase = DefaultMainEditUseCase(userRepository: userRepository, index: index)
        let viewModel = MainEditViewModel(useCase: useCase)
        let viewController = MainEditViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }
}
