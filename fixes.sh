cd "$1"
sed -i '/OFFSCREENCANVAS_SUPPORT/d' CMakeLists.txt
grep -n OFFSCREEN CMakeLists.txt
