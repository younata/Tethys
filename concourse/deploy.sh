#!/bin/bash

cd rssclient
carthage bootstrap --platform ios
bundle
bundle exec fastlane deploy_setup

if [[ `git name-rev --name-only --tags HEAD` = 'undefined' ]]
then
    bundle exec fastlane deploy_testflight
else
    bundle exec fastlane deploy_app_store
fi

