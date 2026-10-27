#!/bin/sh
# Builds sqlanywhere.so (NTS and ZTS) for Linux x64 using the official PHP Docker images.
# usage: build/build-linux.sh [php-minor]   e.g. build/build-linux.sh 8.5
# Output (same layout as the SAP distribution):
#   dist/php-<minor>/linux/lib64/php-<minor>.0_sqlanywhere.so.1    (NTS)
#   dist/php-<minor>/linux/lib64/php-<minor>.0_sqlanywhere_r.so.1  (ZTS, uses libdbcapi_r.so)
#   plus the unversioned .so symlinks, packed into
#   dist/php-<minor>/SQLAnywhere-php-<minor>_Linux.tar.gz
set -e
PHPV=${1:-8.5}
SRC=$(cd "$(dirname "$0")/.." && pwd)
OUT="$SRC/dist/php-$PHPV/linux/lib64"
mkdir -p "$OUT"

for TAG in cli zts; do
    echo "=== php:$PHPV-$TAG ==="
    MSYS_NO_PATHCONV=1 docker run --rm -v "$SRC:/src:ro" -v "$OUT:/out" "php:$PHPV-$TAG" sh -c '
        set -e
        cp -r /src /build && cd /build
        phpize >/dev/null
        ./configure --with-sqlanywhere >/dev/null
        make >/dev/null
        V=$(php -r "echo PHP_ZTS ? \"_r\" : \"\";")
        cp modules/sqlanywhere.so /out/php-'"$PHPV"'.0_sqlanywhere$V.so.1
        php -d extension=/build/modules/sqlanywhere.so -r "echo PHP_VERSION, \" \", PHP_ZTS?\"ZTS\":\"NTS\", \" loaded=\", var_export(extension_loaded(\"sqlanywhere\"), true), PHP_EOL;" 2>/dev/null
    '
done

# symlinks are created on the host (bind mounts on Windows cannot hold them)
cd "$OUT"
for V in "" _r; do
    rm -f "php-$PHPV.0_sqlanywhere$V.so"
    MSYS=winsymlinks:nativestrict ln -s "php-$PHPV.0_sqlanywhere$V.so.1" "php-$PHPV.0_sqlanywhere$V.so" \
        || cp "php-$PHPV.0_sqlanywhere$V.so.1" "php-$PHPV.0_sqlanywhere$V.so"
done
ls -la "$OUT"

# targets go before the symlinks so the archive also extracts on Windows
cd "$OUT/.."
ARC="../SQLAnywhere-php-${PHPV}_Linux.tar.gz"
tar --owner=0 --group=0 --mode=755 --no-recursion -czf "$ARC" lib64 \
    "lib64/php-$PHPV.0_sqlanywhere.so.1" "lib64/php-$PHPV.0_sqlanywhere_r.so.1" \
    "lib64/php-$PHPV.0_sqlanywhere.so" "lib64/php-$PHPV.0_sqlanywhere_r.so"
tar -tvzf "$ARC"
