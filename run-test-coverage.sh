#!/bin/bash

echo "[REMOVING ./coverage DIRECTORY]"
rm -rf ./coverage

echo ""
echo "[RUNNING TEST + COVERAGE]"
pub run test_coverage --no-badge --print-test-output  --min-coverage 40

echo ""
echo "[GENERATING COVERAGE REPORT AT ./coverage]"
genhtml ./coverage/lcov.info -o coverage

echo ""
echo "[OPENING ./coverage/index.html]"
open ./coverage/index.html
