#!/bin/bash

cd tethys_github
bundle
carthage bootstrap --platform ios,mac --no-use-binaries
bundle exec rake documentation:libraries
bundle exec fastlane test
