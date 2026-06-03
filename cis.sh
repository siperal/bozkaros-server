#!/bin/bash
git submodule update --recursive --remote
rm -f ./cis/bozkarcis.tar.gz
tar -czf "./cis/bozkarcis.tar.gz" bozkarcis