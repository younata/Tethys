require 'semantic'
require 'tempfile'
require 'rest-client'
require 'json'
require 'octokit'

def run(command)
  system(command) or raise "RAKE TASK FAILED: #{command}"
end

namespace "test" do
  namespace "ios" do
    desc "Run unit tests for the iOS app"
    task :app do |t|
      puts "running tests for the iOS app"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme RSSClientTests -destination 'platform=iOS Simulator,name=iPhone 6' test | xcpretty -c && echo 'iOS App Tests Passed'"
    end

    desc "Run unit tests for the iOS kit"
    task :kit do |t|
      puts "Running tests for the iOS kit"
      run "set -o pipefail && xcodebuild -project RSSClient.xcodeproj -scheme rNewsKitTests -destination 'platform=iOS Simulator,name=iPhone 6' test | xcpretty -c && echo 'iOS Kit tests Passed'"
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

namespace "documentation" do
  desc "Generate library information"
  task :libraries do |t|
    cartfile = IO.read('Cartfile')
    markdown_string = "rNews utilizes the following third party libraries:\n\n"

    dependencies = cartfile.each_line do |line|
      line = line[/[^#]+/]
      source, full_name = line.split(' ')[0, 2].map { |f| f.gsub('"', '') }
      unless source.nil? or full_name.nil?
        name = full_name.split('/').last.gsub('.git', '')
        if source == 'github'
          url = "https://github.com/#{full_name}"
        else
          url = full_name
        end
        markdown_string += "- [#{name}](#{url})\n"
      end
    end

    require 'kramdown'

    html_string = Kramdown::Document.new(markdown_string).to_html

    IO.write("documentation/libraries.html", html_string)

    puts 'Wrote library information to documentation/libraries.html'
  end
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
    run "/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString #{version}' 'RSSClient/Supporting Files/Info.plist'"
    build_version = `/usr/libexec/PlistBuddy -c 'print :CFBundleVersion' 'RSSClient/Supporting Files/Info.plist'`.strip().to_i
    run "/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion #{build_version + 1}' 'RSSClient/Supporting Files/Info.plist'"
  end

  desc "Commits and pushes a release of the new version"
  task :publish do |t|
    puts "Enter new version number: "
    new_version = STDIN.gets.chomp
    Semantic::Version.new new_version
    bump_version new_version

    message = draft_release_notes
    run "git add fastlane/metadata/en-US/release_notes.txt"
    run "git add 'RSSClient/Supporting Files/Info.plist'"
    version = `/usr/libexec/PlistBuddy -c 'print :CFBundleShortVersionString' 'RSSClient/Supporting Files/Info.plist'`.strip()

    run "git ci -m '#{version}'"

    version_str = "v#{version}"
    puts "Tagging version"
    run "git tag #{version_str}"
    puts "Pushing to github"
    run "git push origin head && git push origin #{version_str}"

    release_token = IO.read(".release_token").strip()

    version_str = "v#{version}"

    puts "Creating github release"

    client = Octokit::Client.new(:access_token => release_token)
    client.create_release("younata/RSSClient", version_str, {:name => version, :body => message})
    if 200 <= client.last_response.status or client.last_response_status <= 300
      puts 'Successfully uploaded release'
    else
      puts 'Error uploading release'
    end
  end
end

task :test => ["test:ios", "test:osx"]

desc "Runs Synx (synchronizes directory structure with xcode project structure)"
task :synx do |t|
    run 'synx -e /RSSClient/Frameworks -e /RSSClientTests/Frameworks -e /RSSClient-OSX/Frameworks -e /rNewsKit-OSX -e /rNewsKit-OSXTests RSSClient.xcodeproj/'
end

task default: ["test"]

