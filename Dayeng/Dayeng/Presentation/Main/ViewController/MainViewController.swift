//
//  MainViewController.swift
//  Dayeng
//
//  Created by 조승기 on 2023/01/31.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class MainViewController: UIViewController {
    // MARK: - UI properties
    private var collectionView: UICollectionView!
    
    private lazy var friendButton = {
        var button: UIButton = UIButton()
        button.tintColor = .black
        let image = UIImage(systemName: "person.2.fill",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 35))
        button.setImage(image, for: .normal)
        return button
    }()
    
    private lazy var settingButton = {
        var button: UIButton = UIButton()
        button.tintColor = .black
        let image = UIImage(systemName: "gear",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 35))
        button.setImage(image, for: .normal)
        return button
    }()
    
    private lazy var calendarButton = UIBarButtonItem(
        image: UIImage(systemName: "calendar"),
        style: .plain,
        target: nil,
        action: nil)
    
    // MARK: - Properties
    var disposeBag = DisposeBag()
    private let viewModel: MainViewModel
    private let editButtonDidTapped = PublishRelay<Int>()
    private let titleViewDidTapped = PublishRelay<Void>()
    private var editButtonDisposables = [Int: Disposable]()
    private var initialIndexPath: IndexPath?
    
    // MARK: - Lifecycles
    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideIndicator()
        setupNaviagationBar()
        configureCollectionView()
        setupViews()
        bind()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        hideIndicator()
    }
    
    // MARK: - Helpers
    private func setupNaviagationBar() {
        let titleImageView = UIImageView(image: .dayengLogo)
        let tapGestureRecognizer = UITapGestureRecognizer()
        titleImageView.isUserInteractionEnabled = true
        titleImageView.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.rx.event.map { _ in }
            .bind(to: titleViewDidTapped)
            .disposed(by: disposeBag)
        
        navigationItem.titleView = titleImageView
        navigationController?.navigationBar.tintColor = .black
        
        navigationItem.title = ""
        navigationController?.navigationBar.topItem?.title = ""
    }
    
    private func setupViews() {
        view.addBackgroundImage()
        [collectionView, friendButton, settingButton].forEach {
            view.addSubview($0)
        }
        configureUI()
    }
    
    private func configureUI() {
        collectionView.snp.makeConstraints {
            $0.top.left.right.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalToSuperview()
        }
        
        friendButton.snp.makeConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            $0.right.equalToSuperview().offset(-55)
            $0.height.width.equalTo(50)
        }
        
        settingButton.snp.makeConstraints {
            $0.bottom.equalTo(friendButton.snp.bottom)
            $0.right.equalToSuperview().offset(-10)
            $0.height.width.equalTo(50)
        }
    }
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout())
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(MainCell.self, forCellWithReuseIdentifier: MainCell.identifier)
        collectionView.isPagingEnabled = true
        collectionView.isScrollEnabled = false
        collectionView.bounces = false
        collectionView.backgroundColor = .clear
    }
    
    private func collectionViewLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .paging
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    func bind() {
        let input = MainViewModel.Input(
            viewWillAppear: rx.viewWillAppear.map { _ in }.asObservable(),
            friendButtonDidTapped: friendButton.rx.tap.asObservable(),
            settingButtonDidTapped: settingButton.rx.tap.asObservable(),
            calendarButtonDidTapped: calendarButton.rx.tap.asObservable(),
            edidButtonDidTapped: editButtonDidTapped.asObservable()
        )
        
        editButtonDidTapped
            .subscribe(onNext: { [weak self] _ in
                guard let self else { return }
                self.showIndicator()
            }).disposed(by: disposeBag)
        
        let output = viewModel.transform(input: input)
        
        output.questionsAnswers
            .bind(to: collectionView.rx.items(cellIdentifier: MainCell.identifier, cellType: MainCell.self)
            ) { (index, questionAnswer, cell) in
                let (question, answer) = questionAnswer
                cell.mainView.bind(question, answer)
            }
            .disposed(by: disposeBag)
        
        output.firstShowingIndex
            .subscribe(onNext: { [weak self] index in
                guard let self, let index = index else { return }
                self.initialIndexPath = IndexPath(row: index, section: 0)
            })
            .disposed(by: disposeBag)
        
        titleViewDidTapped.withLatestFrom(output.startBluringIndex)
            .subscribe(onNext: { [weak self] startBluringIndex in
                guard let self else { return }
                let indexPath = IndexPath(
                    row: (startBluringIndex ?? output.questionsAnswers.value.count)-1,
                    section: 0
                )
                
                self.collectionView.scrollToItem(at: indexPath,
                                                 at: .centeredVertically,
                                                 animated: true)
            })
            .disposed(by: disposeBag)

        output.startBluringIndex
            .subscribe(onNext: { [weak self] startBluringIndex in
                guard let self else { return }
                if let showingIndex = output.firstShowingIndex.value {
                    self.initialIndexPath = IndexPath(row: showingIndex, section: 0)
                    return
                }
                self.initialIndexPath = IndexPath(
                    row: (startBluringIndex ?? output.questionsAnswers.value.count)-1,
                    section: 0)
            })
            .disposed(by: disposeBag)
    
        if output.ownerType != .mine {
            bindFriend(output: output)
            return
        }
        
        navigationItem.leftBarButtonItem = calendarButton
        
        collectionView.rx.willDisplayCell
            .subscribe(onNext: { [weak self] cell, indexPath in
                guard let self,
                      let cell = cell as? MainCell else { return }
                
                if let initialIndexPath = self.initialIndexPath {
                    self.collectionView.scrollToItem(at: initialIndexPath,
                                                     at: .centeredVertically,
                                                     animated: false)
                    self.initialIndexPath = nil
                }
                
                self.editButtonDisposables[indexPath.row] = cell.mainView.editButtonDidTapped
                    .map { indexPath.row }
                    .bind(to: self.editButtonDidTapped)
                guard let blurIndex = output.startBluringIndex.value else { return }
                if indexPath.row >= blurIndex {
                    cell.blur()
                }
            })
            .disposed(by: disposeBag)
        
        collectionView.rx.didEndDisplayingCell
            .subscribe(onNext: { [weak self] _, indexPath in
                guard let self else { return }
                self.editButtonDisposables[indexPath.row]?.dispose()
                self.editButtonDisposables.removeValue(forKey: indexPath.row)
            })
            .disposed(by: disposeBag)
    }
    
    private func bindFriend(output: MainViewModel.Output) {
        friendButton.isHidden = true
        settingButton.isHidden = true
        collectionView.rx.willDisplayCell
            .subscribe(onNext: { [weak self] _, _ in
                guard let self else { return }
                if let initialIndexPath = self.initialIndexPath {
                    self.collectionView.scrollToItem(at: initialIndexPath,
                                                     at: .centeredVertically,
                                                     animated: false)
                    self.initialIndexPath = nil
                }
            })
            .disposed(by: disposeBag)
    }
}
