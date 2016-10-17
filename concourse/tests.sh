#!/bin/bash

cd rssclient
carthage bootstrap --platform ios
bundle
bundle exec fastlane test
