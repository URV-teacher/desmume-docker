#!/bin/bash
set -eo pipefail

rm -rf /tmp/hello-world-nds
git clone https://github.com/URV-teacher/hello-world-nds.git /tmp/hello-world-nds

(
  cd hello-world-nds
  make
  make run
)
rm -rf hello-world-nds