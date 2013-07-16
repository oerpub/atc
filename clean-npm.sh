#!/bin/bash
# This script just removes library files installed by npm install so that you can do a clean
# npm install
rm -rf node_modules/
rm -rf scripts/libs/
