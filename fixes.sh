cd "$1"
sed -i '/OFFSCREENCANVAS_SUPPORT/d' CMakeLists.txt
sed -i 's/-sASSERTIONS=1/-sASSERTIONS=1 --profiling-funcs/' CMakeLists.txt
grep -n -E 'OFFSCREEN|profiling' CMakeLists.txt
