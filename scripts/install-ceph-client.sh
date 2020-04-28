#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -yq python ceph-common ceph-fuse
