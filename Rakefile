def run(command)
  system(command) or raise "RAKE TASK FAILED: #{command}"
end

namespace "test" do
  desc "Run unit tests for all iOS targets"
  task :ios do |t|
    run "xcodebuild -project RSSClient.xcodeproj -scheme RSSClientTests -destination 'platform=iOS Simulator,name=iPhone 5s,OS=8.3' test | xcpretty -c -t"
  end

  desc "Run unit tests for all OS X targets"
  task :osx do |t|
    run "xcodebuild -project RSSClient.xcodeproj -scheme RSSClient-OSX test"
  end
end

task default: ["test:ios"]


