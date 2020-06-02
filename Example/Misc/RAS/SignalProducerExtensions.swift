import ReactiveSwift

extension SignalProducer {
    public func replaceError(_ transform: @escaping (Error) -> Value) -> SignalProducer<Value, Never> {
        return flatMapError { SignalProducer<Value, Never>(value: transform($0)) }
    }
}
