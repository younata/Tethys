#!/bin/bash -el

cd code
bundle
carthage bootstrap --platform ios --no-use-binaries
bundle exec rake documentation:libraries
echo "$MIXPANEL_TOKEN" > .mixpanel
echo "$PASIPHAE_TOKEN" > .pasiphae
echo "$PASIPHAE_URL" > .pasiphaeURL

bundle exec fastlane deploy_testflight_external
