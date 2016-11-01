#!/bin/bash

cd rssclient
bundle
bundle exec carthage_cache -b $AWS_CACHE_BUCKET install || carthage bootstrap --no-use-binaries --platform ios
echo "$MIXPANEL_TOKEN" > .mixpanel
echo "$PASIPHAE_TOKEN" > .pasiphae
echo "$PASIPHAE_URL" > .pasiphaeURL

if [[ `git name-rev --name-only --tags HEAD` = 'undefined' ]]
then
    bundle exec fastlane deploy_testflight
else
    bundle exec fastlane deploy_app_store
fi

