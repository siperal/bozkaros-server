#!/bin/bash
git submodule update --recursive --remote
mkdir -p ./cis
rm -f ./cis/bozkarcis.tar.gz
tar -czf "./cis/bozkarcis.tar.gz" bozkarcis