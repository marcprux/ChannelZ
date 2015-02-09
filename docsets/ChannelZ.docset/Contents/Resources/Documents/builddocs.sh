#!/bin/sh -e
cd ../master/
jazzy --output ../gh-pages --author GlimpseIO --author_url http://glimpse.io --module ChannelZ --github_url https://github.com/GlimpseIO/ChannelZ --skip-undocumented
