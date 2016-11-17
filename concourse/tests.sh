#!/bin/bash

cd tethys_github
bundle
carthage update --no-build --no-use-binaries
bundle exec carthage_cache -b $AWS_CACHE_BUCKET install || (carthage bootstrap --platform ios,mac --no-use-binaries; bundle exec carthage_cache -b $AWS_CACHE_BUCKET publish)
bundle exec rake documentation:libraries
bundle exec fastlane test
