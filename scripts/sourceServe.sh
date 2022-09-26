#!/bin/bash
# A sample Bash script
echo Starting Sourcemap Update	# This is a comment, too!
rojo sourcemap demo.project.json --output sourcemap.json
echo Restarting Rojo
rojo serve demo.project.json
echo Done