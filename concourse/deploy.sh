#!/bin/bash

cd rssclient
carthage bootstrap --platform ios
bundle
echo "$MIXPANEL_TOKEN" > .mixpanel
echo "$PASIPHAE_TOKEN" > .pasiphae
echo "$PASIPHAE_URL" > .pasiphaeURL

if [[ `git name-rev --name-only --tags HEAD` = 'undefined' ]]
then
    bundle exec fastlane deploy_testflight
else
    bundle exec fastlane deploy_app_store
fi

