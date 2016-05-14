import JavaScriptCore

public protocol ScriptService {
    func runScript<T: AnyObject>(script: String, arguments: [AnyObject]) -> [T]
}

struct JavaScriptService: ScriptService {
    func runScript<T: AnyObject>(script: String, arguments: [AnyObject]) -> [T] {
        let context = JSContext()
        context.exceptionHandler = { _, exception in
            print("JS Error: \(exception)")
        }
        context.evaluateScript(script)
        let function = context.objectForKeyedSubscript("script")
        let res = function.callWithArguments(arguments).toArray()
        return res as? [T] ?? []
    }
}
