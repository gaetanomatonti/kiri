import Dispatch
import Foundation

struct Process {
  static func run(onExit: @escaping () -> Void) {
    signal(SIGINT, SIG_IGN)

    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler {
      onExit()
      exit(0)
    }
    sigintSource.resume()
    dispatchMain()
  }
}
