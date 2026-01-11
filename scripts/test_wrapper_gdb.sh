#!/bin/bash
set -eo pipefail

desmume $@ >> $DESMUME/DeSmuME.exe
chmod +x $DESMUME/DeSmuME.exe
