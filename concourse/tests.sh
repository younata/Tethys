#!/bin/bash

cd rssclient
bundle
bundle exec carthage_cache -b $AWS_CACHE_BUCKET install || (carthage bootstrap --platform ios,mac; bundle exec carthage_cache -b $AWS_CACHE_BUCKET publish)
bundle exec fastlane test
