#!/bin/bash

cd tethys_github
bundle
bundle exec carthage_cache -b $AWS_CACHE_BUCKET install || carthage bootstrap --no-use-binaries --platform ios
bundle exec rake documentation:libraries
echo "$MIXPANEL_TOKEN" > .mixpanel
echo "$PASIPHAE_TOKEN" > .pasiphae
echo "$PASIPHAE_URL" > .pasiphaeURL

CURRENT_TAG=`git name-rev --name-only --tags HEAD`
shopt -s nocasematch

if [[ "$CURRENT_TAG" = 'undefined' ]]
then
    bundle exec fastlane deploy_testflight
elif [[ "$CURRENT_TAG" =~ [RC\d$] ]]
then
    bundle exec fastlane deploy_testflight_external
else
    bundle exec fastlane deploy_app_store
fi

