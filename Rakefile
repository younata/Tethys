def run(command)
  system(command) or raise "RAKE TASK FAILED: #{command}"
end

namespace "test" do
  namespace "ios" do
    desc "Run unit tests for the iOS app"
    task :app do |t|
      puts "running tests for the iOS app"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme RSSClientTests -destination 'platform=iOS Simulator,name=iPhone 6' test | xcpretty -c --formatter scripts/xcpretty-formatter.rb && echo 'iOS App Tests Passed'"
    end

    desc "Run unit tests for the iOS kit"
    task :kit do |t|
      puts "Running tests for the iOS kit"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme rNewsKitTests -destination 'platform=iOS Simulator,name=iPhone 6' test | xcpretty -c --formatter scripts/xcpretty-formatter.rb && echo 'iOS Kit tests Passed'"
    end

    desc "Run acceptance (UI) tests for the iOS app"
    task :ui do |t|
      puts "running acceptance tests for the iOS app"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme rNewsAcceptanceTests -destination 'platform=iOS Simulator,name=iPhone 6' test | xcpretty -c --formatter scripts/xcpretty-formatter.rb && echo 'iOS UI Tests Passed'"
    end
  end
  desc "Run unit tests for all iOS targets"
  task :ios=> ["ios:app", "ios:kit", "ios:ui"]

  namespace "osx" do
    desc "Run unit tests for the OS X app"
    task :app do |t|
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme rNews-OSXTests test 2>/dev/null | xcpretty -c --formatter scripts/xcpretty-formatter.rb && echo 'OSX App tests Passed'"
    end

    desc "Run unit tests for the OS X kit"
    task :kit do |t|
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme rNewsKit-OSXTests test 2>/dev/null | xcpretty -c --formatter scripts/xcpretty-formatter.rb && echo 'OSX Kit tests Passed'"
    end
  end
  desc "Run unit tests for all OS X targets"
  task :osx => ["osx:app", "osx:kit"]
end

task :test => ["test:ios", "test:osx"]

task default: ["test"]


