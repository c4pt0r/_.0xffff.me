#!/bin/sh
# Build script for Vercel

# Convert markdown files to HTML using Node.js
echo "Converting markdown files to HTML..."
node convert-md.js

# get saait
wget https://codemadness.org/releases/saait/saait-0.8.tar.gz
tar zxvf ./saait-0.8.tar.gz
cd saait-0.8; make; cd .. 

# check if saait successfuly built

if [ -f ./saait-0.8/saait ]; then
    export PATH=./saait-0.8:$PATH
else
    echo "saait build failed"
    exit 1
fi

mkdir -p output
find ../pages -type f -name '*.cfg' -print0 | sort -zr | xargs -0 saait -t ../templates -c ../config.cfg
cp ../style.css ../print.css ../public.asc ../script.js output/
cp -r ../statics output/

# copy to public directory
rm -rf ../public
cp -r ./output ../public
