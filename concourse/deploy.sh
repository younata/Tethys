#!/bin/bash -el

cd tethys_github
bundle
carthage bootstrap --platform ios --no-use-binaries
bundle exec rake documentation:libraries
echo "$MIXPANEL_TOKEN" > .mixpanel
echo "$PASIPHAE_TOKEN" > .pasiphae
echo "$PASIPHAE_URL" > .pasiphaeURL

CURRENT_TAG=`git name-rev --name-only --tags HEAD`
shopt -s nocasematch

if [[ "$CURRENT_TAG" = 'undefined' ]]
then
    bundle exec fastlane deploy_testflight
else
    bundle exec fastlane deploy_app_store
fi
