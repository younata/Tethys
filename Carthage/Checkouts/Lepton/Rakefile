def run(command)
  system(command) or raise "RAKE TASK FAILED: #{command}"
end

namespace "test" do
  desc "Run unit tests for all iOS targets"
  task :ios do |t|
    run "set -o pipefail && xcodebuild -project Lepton.xcodeproj -scheme Lepton-iOSTests -destination 'platform=iOS Simulator,name=iPhone 6' test 2>/dev/null | xcpretty -c && echo 'Tests succeeded'"
  end

  desc "Run unit tests for all OS X targets"
  task :osx do |t|
    run "set -o pipefail && xcodebuild -project Lepton.xcodeproj -scheme Lepton-OSXTests test 2>/dev/null | xcpretty -c && echo 'Tests succeeded'"
  end
end

task default: ["test:ios", "test:osx"]
