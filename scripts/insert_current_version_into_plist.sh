#/bin/sh

set -x

infoplist="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

pushd ${PROJECT_DIR} 2>/dev/null >/dev/null
contents=`git describe --tags`
popd 2>/dev/null >/dev/null

/usr/libexec/PlistBuddy -c "Add :CurrentGitVersion string ${contents}" "${infoplist}"
/usr/libexec/PlistBuddy -c "Set :CurrentGitVersion ${contents}" "${infoplist}"
