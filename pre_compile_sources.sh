#!/bin/sh

#  pre_compile_sources.sh
#  Krypton
#
#  Created by Alex Grinman on 6/13/18.
#  Copyright © 2018 KryptCo. All rights reserved.

modulesDirectory=$DERIVED_FILES_DIR/modules
modulesMap=$modulesDirectory/module.modulemap
modulesMapTemp=$modulesDirectory/module.modulemap.tmp

mkdir -p "$modulesDirectory"

cat > "$modulesMapTemp" << MAP
module CommonCrypto [system] {
    header "$SDKROOT/usr/include/CommonCrypto/CommonCrypto.h"
    export *
}
MAP

diff "$modulesMapTemp" "$modulesMap" >/dev/null 2>/dev/null
if [[ $? != 0 ]] ; then
mv "$modulesMapTemp" "$modulesMap"
else
rm "$modulesMapTemp"
fi
