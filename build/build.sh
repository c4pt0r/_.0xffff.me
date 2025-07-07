#!/bin/sh
# Build script for Vercel

# make sure wget and markdown processor are installed
yum -y install wget
# Install markdown processor (using lowdown which is lightweight)
yum -y install lowdown || (
    # If lowdown is not available, try to install from source
    wget https://kristaps.bsd.lv/lowdown/snapshots/lowdown.tar.gz
    tar xzf lowdown.tar.gz
    cd lowdown-*/
    make
    make install PREFIX=/usr/local
    cd ..
    rm -rf lowdown-*/
)

# Convert markdown files to HTML
echo "Converting markdown files to HTML..."
for md_file in ../pages/*.md; do
    if [ -f "$md_file" ]; then
        # Extract base name without extension
        base_name=$(basename "$md_file" .md)
        html_file="../pages/${base_name}.html"
        
        # Convert markdown to HTML and wrap in basic HTML structure
        echo "<!DOCTYPE html>" > "$html_file"
        echo "<html>" >> "$html_file"
        lowdown "$md_file" >> "$html_file"
        echo "</html>" >> "$html_file"
        
        echo "Converted $md_file to $html_file"
    fi
done

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

# copy to public directory
rm -rf ../public
cp -r ./output ../public
