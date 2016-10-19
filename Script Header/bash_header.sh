#!/bin/bash

if [ -t 0 ]; then
	# stdin is a tty
	echo "STDIN is a TTY..."
else
	IFS= read -r -t 10 stdin
	if [[ "${stdin}" != "" ]]; then
		echo "STDIN arg: ${stdin}"
	else 
		echo "No STDIN argument passed..."
	fi
fi

arg_1=${1}
if [[ "${arg_1}" != "" ]]; then
	echo "Argument 1: ${arg_1}"
else 
	echo "No Argument 1 passed..."
fi


exit 0