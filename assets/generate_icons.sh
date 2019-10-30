#!/bin/bash -e

export APP_NAME=Tethys

function settings_icon {
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml ../$APP_NAME/Assets.xcassets/settings.imageset/settings@2x.png 48:48
svgexport AppIcon.xml ../$APP_NAME/Assets.xcassets/settings.imageset/settings@3x.png 72:72
EOF
}

function chevron_icons {
    parallel --progress -j 0 << EOF
svgexport Chevron.xml Chevron@2x.png 48:48
svgexport Chevron.xml Chevron@3x.png 72:72
EOF

    parallel --progress -j 0 << EOF
convert Chevron@2x.png -rotate -90 ../$APP_NAME/Assets.xcassets/LeftChevron.imageset/LeftChevron@2x.png
convert Chevron@3x.png -rotate -90 ../$APP_NAME/Assets.xcassets/LeftChevron.imageset/LeftChevron@3x.png
convert Chevron@2x.png -rotate 90 ../$APP_NAME/Assets.xcassets/RightChevron.imageset/RightChevron@2x.png
convert Chevron@3x.png -rotate 90 ../$APP_NAME/Assets.xcassets/RightChevron.imageset/RightChevron@3x.png
EOF
    rm Chevron@2x.png Chevron@3x.png
}

function app_icon {
    export ASSET_PATH="../$APP_NAME/Assets.xcassets/AppIcon.appiconset"
    export ICON_ASSET_PATH="../$APP_NAME/Assets.xcassets/App\ Icons/DefaultAppIcon.imageset"
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml $ICON_ASSET_PATH/DefaultAppIcon.png 60:60
svgexport AppIcon.xml $ICON_ASSET_PATH/DefaultAppIcon.png 120:120
svgexport AppIcon.xml $ICON_ASSET_PATH/DefaultAppIcon@3x.png 180:180
svgexport AppIcon.xml $ASSET_PATH/Icon@2x.png 120:120
svgexport AppIcon.xml $ASSET_PATH/Icon@3x.png 180:180
svgexport AppIcon.xml $ASSET_PATH/Icon-iPadPro@2x.png 167:167
svgexport AppIcon.xml $ASSET_PATH/Icon-iPad.png 76:76
svgexport AppIcon.xml $ASSET_PATH/Icon-iPad@2x.png 152:152
svgexport AppIcon.xml $ASSET_PATH/Icon-AppStore.png 1024:1024
EOF
    parallel --progress -j 0 << EOF
convert $ICON_ASSET_PATH/DefaultAppIcon.png -background white -alpha remove $ICON_ASSET_PATH/DefaultAppIcon.png
convert $ICON_ASSET_PATH/DefaultAppIcon@2x.png -background white -alpha remove $ICON_ASSET_PATH/DefaultAppIcon@2x.png
convert $ICON_ASSET_PATH/DefaultAppIcon@3x.png -background white -alpha remove $ICON_ASSET_PATH/DefaultAppIcon@3x.png
convert $ASSET_PATH/Icon@2x.png -background white -alpha remove $ASSET_PATH/Icon@2x.png
convert $ASSET_PATH/Icon@3x.png -background white -alpha remove $ASSET_PATH/Icon@3x.png
convert $ASSET_PATH/Icon-iPadPro@2x.png -background white -alpha remove $ASSET_PATH/Icon-iPadPro@2x.png
convert $ASSET_PATH/Icon-iPad.png -background white -alpha remove $ASSET_PATH/Icon-iPad.png
convert $ASSET_PATH/Icon-iPad@2x.png -background white -alpha remove $ASSET_PATH/Icon-iPad@2x.png
convert $ASSET_PATH/Icon-AppStore.png -background white -alpha remove $ASSET_PATH/Icon-AppStore.png
EOF
}

function app_icon_black {
    export ASSET_PATH="../$APP_NAME/AlternateIcons"
    export ICON_ASSET_PATH="../$APP_NAME/Assets.xcassets/App\ Icons/BlackAppIcon.imageset"
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml $ICON_ASSET_PATH/BlackAppIcon.png 60:60
svgexport AppIcon.xml $ICON_ASSET_PATH/BlackAppIcon@2x.png 120:120
svgexport AppIcon.xml $ICON_ASSET_PATH/BlackAppIcon@3x.png 180:180
svgexport AppIcon.xml $ASSET_PATH/AppIcon-Black.png 60:60
svgexport AppIcon.xml $ASSET_PATH/AppIcon-Black@2x.png 120:120
svgexport AppIcon.xml $ASSET_PATH/AppIcon-Black@3x.png 180:180
svgexport AppIcon.xml $ASSET_PATH/AppIcon-Black-iPad.png 76:76
svgexport AppIcon.xml $ASSET_PATH/AppIcon-Black-iPad@2x.png 152:152
svgexport AppIcon.xml $ASSET_PATH/AppIcon-Black-iPadPro@2x.png 167:167
EOF
    parallel --progress -j 0 << EOF
convert $ICON_ASSET_PATH/BlackAppIcon.png -background black -alpha remove $ICON_ASSET_PATH/BlackAppIcon.png
convert $ICON_ASSET_PATH/BlackAppIcon@2x.png -background black -alpha remove $ICON_ASSET_PATH/BlackAppIcon@2x.png
convert $ICON_ASSET_PATH/BlackAppIcon@3x.png -background black -alpha remove $ICON_ASSET_PATH/BlackAppIcon@3x.png
convert $ASSET_PATH/AppIcon-Black.png -background black -alpha remove $ASSET_PATH/AppIcon-Black.png
convert $ASSET_PATH/AppIcon-Black@2x.png -background black -alpha remove $ASSET_PATH/AppIcon-Black@2x.png
convert $ASSET_PATH/AppIcon-Black@3x.png -background black -alpha remove $ASSET_PATH/AppIcon-Black@3x.png
convert $ASSET_PATH/AppIcon-Black-iPad.png -background black -alpha remove $ASSET_PATH/AppIcon-Black-iPad.png
convert $ASSET_PATH/AppIcon-Black-iPad@2x.png -background black -alpha remove $ASSET_PATH/AppIcon-Black-iPad@2x.png
convert $ASSET_PATH/AppIcon-Black-iPadPro@2x.png -background black -alpha remove $ASSET_PATH/AppIcon-Black-iPadPro@2x.png
EOF
}

function gray_icon {
    export ASSET_PATH="../$APP_NAME/Assets.xcassets/GrayIcon.imageset"
    parallel --progress -j 0 << EOF
svgexport GrayIcon.xml $ASSET_PATH/GrayIcon@2x.png 120:120
svgexport GrayIcon.xml $ASSET_PATH/GrayIcon@3x.png 180:180
EOF
}

function markread_icons {
    parallel --progress -j 0 << EOF
svgexport MarkRead.xml ../$APP_NAME/Assets.xcassets/MarkRead.imageset/MarkRead.png 25:25
svgexport MarkRead.xml ../$APP_NAME/Assets.xcassets/MarkRead.imageset/MarkRead@2x.png 50:50
svgexport MarkRead.xml ../$APP_NAME/Assets.xcassets/MarkRead.imageset/MarkRead@3x.png 75:75
svgexport MarkUnread.xml ../$APP_NAME/Assets.xcassets/MarkUnread.imageset/MarkUnread.png 25:25
svgexport MarkUnread.xml ../$APP_NAME/Assets.xcassets/MarkUnread.imageset/MarkUnread@2x.png 50:50
svgexport MarkUnread.xml ../$APP_NAME/Assets.xcassets/MarkUnread.imageset/MarkUnread@3x.png 75:75
EOF
}

function checkmark_icon {
    parallel --progress -j 0 << EOF
svgexport Checkmark.xml ../$APP_NAME/Assets.xcassets/Checkmark.imageset/Checkmark.png 25:25
svgexport Checkmark.xml ../$APP_NAME/Assets.xcassets/Checkmark.imageset/Checkmark@2x.png 50:50
svgexport Checkmark.xml ../$APP_NAME/Assets.xcassets/Checkmark.imageset/Checkmark@3x.png 75:75
EOF
}

function eastereggs {
    parallel --progress -j 0 << EOF
svgexport Breakout3DIcon.xml "../$APP_NAME/Assets.xcassets/Easter Eggs/Breakout3DIcon.imageset/Breakout3DIcon.png" 250:250
svgexport Breakout3DIcon.xml "../$APP_NAME/Assets.xcassets/Easter Eggs/Breakout3DIcon.imageset/Breakout3DIcon@2x.png" 500:500
svgexport Breakout3DIcon.xml "../$APP_NAME/Assets.xcassets/Easter Eggs/Breakout3DIcon.imageset/Breakout3DIcon@3x.png" 750:750
svgexport EasterEggUnknown.xml "../$APP_NAME/Assets.xcassets/Easter Eggs/EasterEggUnknown.imageset/EasterEggUnknown.png" 250:250
svgexport EasterEggUnknown.xml "../$APP_NAME/Assets.xcassets/Easter Eggs/EasterEggUnknown.imageset/EasterEggUnknown@2x.png" 500:500
svgexport EasterEggUnknown.xml "../$APP_NAME/Assets.xcassets/Easter Eggs/EasterEggUnknown.imageset/EasterEggUnknown@3x.png" 750:750
EOF
}

if [ ! command -v convert >/dev/null 2>&1 ]; then
    echo "Error: required command 'convert' not found." >&2
    echo "On macOS, install with 'brew install imagemagick" >&2
    exit -1
fi

if [ $# -eq 1 ]; then
    case "$1" in
        "app") app_icon; app_icon_black ;;
        "chevron") chevron_icons ;;
        "checkmark") checkmark_icon ;;
        "eastereggs") eastereggs;;
        "gray") gray_icon ;;
        "markread") markread_icons ;;
        "settings") settings_icon ;;
        *)
            echo "Usage: $0 [app, chevron, checkmark, eastereggs, gray, markread, settings]"
            echo "No arguments will recreate all icons."
            ;;
    esac
else
    export -f app_icon
    export -f app_icon_black
    export -f chevron_icons
    export -f checkmark_icon
    export -f eastereggs
    export -f gray_icon
    export -f settings_icon
    export -f markread_icons 

    parallel --progress -j 0 << EOF
app_icon
app_icon_black
chevron_icons
checkmark_icon
eastereggs
gray_icon
settings_icon
markread_icons
EOF
fi

