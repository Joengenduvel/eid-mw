#!/bin/bash

set -e

pushd $(dirname $0)

source set_eidmw_version.sh
source set_eidmw_username.sh

EIDVIEWER_DMG="eID Viewer-$REL_VERSION.dmg"
EIDVIEWER_BACKUP_DMG="eID Viewer-$REL_VERSION-backup.dmg"

rm -rf release-viewer
mkdir -p release-viewer
rm -f tmp-eidviewer.dmg
rm -f "eID Viewer-$REL_VERSION.dmg"

echo "********** archive and export (in post-archive script) eID Viewer **********"
pushd "../../"
xcodebuild -project "beidmw.xcodeproj" -scheme "eID Viewer" -configuration Release clean archive
popd


echo "********** create eID Viewer DMG **********"
hdiutil create -srcdir release-viewer -volname "eID Viewer" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 100m "tmp-eidviewer.dmg"
DEVNAME=$(hdiutil attach -readwrite -noverify -noautoopen "tmp-eidviewer.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2
mkdir -p "/Volumes/eID Viewer/.background/"
cp -a ../../installers/eid-viewer/mac/bg.png "/Volumes/eID Viewer/.background/"
cp -a "../../export/eID Viewer.app" "/Volumes/eID Viewer/"
ln -s /Applications "/Volumes/eID Viewer/ "
/usr/bin/osascript "../../installers/eid-viewer/mac/setlayout.applescript" "eID Viewer" || true
sleep 4
hdiutil detach $DEVNAME
hdiutil convert tmp-eidviewer.dmg -format UDBZ -o "$EIDVIEWER_DMG"

echo "********** signing the disk image with Developer ID Application **********"
codesign --timestamp --force -o runtime --sign "Developer ID Application" -v "$EIDVIEWER_DMG"



echo "********** notarize the eIDViewer installer **********"
/usr/bin/xcrun altool --notarize-app --primary-bundle-id "be.eid.ViewerInstaller.dmg" --username "$AC_USERNAME" --password "@keychain:altool" --file "$EIDVIEWER_DMG"

echo "********** check notarization history **********"
xcrun altool --notarization-history 0 -u "$AC_USERNAME" -p "@keychain:altool"

#create a backup copy, in case the stapling goes wrong
cp -R "$EIDVIEWER_DMG"  "$EIDVIEWER_BACKUP_DMG"

echo "********** sleep 200 seconds before trying to staple **********"
sleep 200


echo "********** staple the notarization ticket to the DMG **********"
/usr/bin/xcrun stapler staple -v "$EIDVIEWER_DMG"



echo "**** Use the below command to get notarised package identifiers ****"
echo "xcrun altool --notarization-history 0 -u $AC_USERNAME -p @keychain:altool"

echo "**** Then use that [identifier] to get the log url: ****"
echo "xcrun altool --notarization-info [identifier] -u $AC_USERNAME -p @keychain:altool"

echo "**** If the log is ok, but stapling failed due to record not found, retry stapling: ****"
echo "/usr/bin/xcrun stapler staple -v $EIDVIEWER_DMG"


popd
