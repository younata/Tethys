import rNewsKit

class FakeScriptService: ScriptService {
    func runScript<T : AnyObject>(script: String, arguments: [AnyObject]) -> [T] {
        return []
    }
}