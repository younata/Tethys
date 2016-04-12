import Quick
import Nimble
@testable import rNewsKit

class RealmMigratorSpec: QuickSpec {
    override func spec() {
        describe("migrating authors from string-based to type-based") {
            it("creates empty authors for empty strings") {
                let (name, email) = RealmMigrator.nameAndEmailFromAuthorString("")
                expect(name) == ""
                expect(email) == ""
            }
            it("migrates authors without email addresses") {
                let (name, email) = RealmMigrator.nameAndEmailFromAuthorString("foo")
                expect(name) == "foo"
                expect(email) == ""
            }

            it("migrates email addresses without names") {
                let (name, email) = RealmMigrator.nameAndEmailFromAuthorString("<foo@example.com>")
                expect(name) == ""
                expect(email) == "foo@example.com"
            }

            it("migrates single-word authors w/o issues") {
                let (name, email) = RealmMigrator.nameAndEmailFromAuthorString("foo <foo@example.com>")
                expect(name) == "foo"
                expect(email) == "foo@example.com"
            }

            it("migrates multi-word authors w/o issues") {
                let (name, email) = RealmMigrator.nameAndEmailFromAuthorString("foo bar <foo@example.com>")
                expect(name) == "foo bar"
                expect(email) == "foo@example.com"
            }
        }
    }
}
