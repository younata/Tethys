import UIKit
import Ra

public final class MigrationViewController: UIViewController, Injectable {
    private let migrationUseCase: MigrationUseCase

    public init(migrationUseCase: MigrationUseCase) {
        self.migrationUseCase = migrationUseCase
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            migrationUseCase: injector.create(MigrationUseCase)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.migrationUseCase.beginMigration()
    }
}
