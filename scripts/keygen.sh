#!/bin/bash

if [ ! -f .keys/key_rsa ]; then
  mkdir .keys
	ssh-keygen -t rsa -f ./.keys/key_rsa -q -N ''
fi
