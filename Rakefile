def run(command)
  system(command) or raise "RAKE TASK FAILED: #{command}"
end

namespace "test" do
  desc "Run unit tests for all iOS targets"
  task :ios do |t|
    run "xcodebuild -project RSSClient.xcodeproj -scheme RSSClient -destination 'platform=iOS Simulator,name=iPhone 5s,OS=8.1' test"
  end

  desc "Run unit tests for all OS X targets"
  task :osx do |t|
    run "xcodebuild -project RSSClient.xcodeproj -scheme RSSClient-OSX test"
  end
end

task default: ["test:ios"]


