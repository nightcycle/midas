#!/bin/bash
# A sample Bash script
echo Starting Wally Update	# This is a comment, too!
wally install
rojo sourcemap demo.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages
echo Finishing Wally Update	# This is a comment, too!