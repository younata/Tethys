#/bin/sh

set -x

infoplist="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

pushd ${PROJECT_DIR} 2>/dev/null >/dev/null
app_version=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${infoplist}"`
build_number=`/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${infoplist}"`
git_sha=`git rev-parse --short HEAD`
contents="v${app_version}-${build_number}-${git_sha}"
popd 2>/dev/null >/dev/null

/usr/libexec/PlistBuddy -c "Add :CurrentVersion string ${contents}" "${infoplist}"
/usr/libexec/PlistBuddy -c "Set :CurrentVersion ${contents}" "${infoplist}"
