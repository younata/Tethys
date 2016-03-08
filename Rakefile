require 'semantic'
require 'tempfile'
require 'rest-client'
require 'json'

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

namespace "release" do
  def last_git_tag
    `git tag | tail -1`.strip
  end

  def commit_logs_since_version(version)
    `git log #{version}..HEAD --format='%B- %an%n---'`
  end

  def draft_release_notes
    message = commit_logs_since_version(last_git_tag)
    path = Dir::Tmpname.make_tmpname "rnews_release_notes", nil
    IO.write(path, message)

    run "mvim -f #{path}"

    message = IO.read(path)
    File.delete(path)
    IO.write("fastlane/metadata/en-US/release_notes.txt", message)
    message
  end

  def bump_version(version)
    run "/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString #{version}' RSSClient/Supporting Files/Info.plist"
    build_version = `/usr/libexec/PlistBuddy -c 'print :CFBundleVersion' RSSClient/Supporting Files/Info.plist`.strip().to_i
    run "/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion #{build_version + 1}' RSSClient/Supporting Files/Info.plist"
  end

  desc "Commits and pushes a release of the new version"
  task :publish do |t|
    puts "Enter new version number: "
    new_version = STDIN.gets.chomp
    Semantic::Version.new new_version
    bump_version new_version

    message = draft_release_notes
    run "git add fastlane/metadata/en-US/release_notes.txt"
    run "git add RSSClient/Supporting Files/Info.plist"
    version = `/usr/libexec/PlistBuddy -c 'print :CFBundleShortVersionString' RSSClient/Supporting Files/Info.plist`.strip()

    run "git ci -m '#{version}'"

    version_str = "v#{version}"
    puts "Tagging version"
    run "git tag #{version_str}"
    puts "Pushing to github"
    run "git push origin head && git push origin #{version_str}"

    release_token = IO.read(".release_token").strip()

    version_str = "v#{version}"

    body_data = {
        :tag_name => version_str,
        :name => version,
        :body => message
    }

    headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/vnd.github.v3+json'
    }

    puts "Creating github release"

    response = RestClient.post("https://younata:#{release_token}@api.github.com/repos/younata/RSSClient/releases", body_data, headers)

    if response.code == 201
      puts 'Successfully uploaded release'
    else
      puts "Unable to upload release, data: #{response.to_str}"
    end
  end
end

task :test => ["test:ios", "test:osx"]

desc "Runs Synx (synchronizes directory structure with xcode project structure)"
task :synx do |t|
    run 'synx -e /RSSClient/Frameworks -e /RSSClientTests/Frameworks -e /RSSClient-OSX/Frameworks -e /rNewsKit-OSX -e /rNewsKit-OSXTests RSSClient.xcodeproj/'
end

task default: ["test"]

