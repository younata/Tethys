#!/bin/bash

cd tethys_github
bundle
bundle exec carthage_cache -b $AWS_CACHE_BUCKET install || carthage bootstrap --no-use-binaries --platform ios
bundle exec rake documentation:libraries
echo "$MIXPANEL_TOKEN" > .mixpanel
echo "$PASIPHAE_TOKEN" > .pasiphae
echo "$PASIPHAE_URL" > .pasiphaeURL

bundle exec fastlane deploy_testflight_external
