#!/bin/bash -el

cd code
bundle
carthage bootstrap --platform ios,mac --no-use-binaries
bundle exec rake documentation:libraries
bundle exec fastlane test
