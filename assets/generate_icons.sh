#!/bin/bash -e

export APP_NAME=Tethys

function settings_icon {
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/settings.imageset/settings@2x.png 48:48
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/settings.imageset/settings@3x.png 72:72
EOF
}

function app_icon {
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon@2x.png 120:120
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon@3x.png 180:180
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPadPro@2x.png 167:167
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPad.png 76:76
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPad@2x.png 152:152
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-AppStore.png 1024:1024
EOF
    export ASSET_PATH="../$APP_NAME/Images.xcassets/AppIcon.appiconset"
    parallel --progress -j 0 << EOF
convert $ASSET_PATH/Icon@2x.png -background white -alpha remove $ASSET_PATH/Icon@2x.png
convert $ASSET_PATH/Icon@3x.png -background white -alpha remove $ASSET_PATH/Icon@3x.png
convert $ASSET_PATH/Icon-iPadPro@2x.png -background white -alpha remove $ASSET_PATH/Icon-iPadPro@2x.png
convert $ASSET_PATH/Icon-iPad.png -background white -alpha remove $ASSET_PATH/Icon-iPad.png
convert $ASSET_PATH/Icon-iPad@2x.png -background white -alpha remove $ASSET_PATH/Icon-iPad@2x.png
convert $ASSET_PATH/Icon-AppStore.png -background white -alpha remove $ASSET_PATH/Icon-AppStore.png
EOF
}

if [ $# -eq 1 ]; then
    case "$1" in
        "settings") settings_icon ;;
        "app") app_icon ;;
        *)
            echo "Usage: $0 [app, settings]"
            echo "No arguments will recreate all icons."
            ;;
    esac
else
    export -f app_icon
    export -f settings_icon

    parallel --progress -j 0 << EOF
app_icon
settings_icon
EOF
fi

