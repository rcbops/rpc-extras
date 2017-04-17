#!/bin/sh

if (( $# < 1 )); then
    echo "Please provide a tag value."
    exit 1
fi
pushd openstack-ansible
    git fetch
    git checkout $1
popd

git add openstack-ansible

git commit -m "SHA bump for OSA to match $1 as of $(date +%d/%m/%Y)"  --edit
