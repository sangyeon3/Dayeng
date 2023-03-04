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
        let viewModel = MainViewModel()
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
        coordinator.delegate = self
        childCoordinators.append(coordinator)
        coordinator.start()
    }
}

extension MainCoordinator: CoordinatorDelegate {
    func didFinished(childCoordinator: Coordinator) {
        childCoordinators = childCoordinators.filter({ $0 !== childCoordinator })
        delegate?.didFinished(childCoordinator: self)
    }
}
