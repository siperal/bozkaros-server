#!/bin/bash
git submodule update --recursive --remote
rm ./cis/bozkarcis.tar.gz
tar -czf "./cis/bozkarcis.tar.gz" bozkarcis