def run(command)
  system(command) or raise "RAKE TASK FAILED: #{command}"
end

namespace "test" do
  namespace "ios" do
    desc "Run unit tests for the iOS app"
    task :app do |t|
      puts "runnings tests for app"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme RSSClientTests -destination 'platform=iOS Simulator,name=iPhone 6' test 2>/dev/null | xcpretty -c && echo 'App Tests Passed'"
    end

    desc "Run unit tests for the iOS kit"
    task :kit do |t|
      puts "Running tests for kit"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme rNewsKitTests -destination 'platform=iOS Simulator,name=iPhone 6' test 2>/dev/null | xcpretty -c && echo 'Kit tests Passed'"
    end
  end
  desc "Run unit tests for all iOS targets"
  task :ios=> ["ios:app", "ios:kit"]

  desc "Run unit tests for all OS X targets"
  task :osx do |t|
    run "xcodebuild -project RSSClient.xcodeproj -scheme RSSClient-OSX test"
  end
end

task default: ["test:ios"]


