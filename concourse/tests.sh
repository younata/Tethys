#!/bin/bash

cd rssclient
bundle
bundle exec carthage_cache -b $AWS_CACHE_BUCKET install
if [ $? != 0 ]; then
    carthage bootstrap
    bundle exec carthage_cache -b $AWS_CACHE_BUCKET publish
fi
carthage bootstrap --platform ios
bundle exec fastlane test
