#!/bin/sh
# Build script for Vercel

# make sure wget and markdown processor are installed
yum -y install wget
# Install markdown processor (trying multiple options)
yum -y install lowdown || yum -y install markdown || (
    # If no markdown processor available, try to install lowdown from source
    wget https://kristaps.bsd.lv/lowdown/snapshots/lowdown.tar.gz
    tar xzf lowdown.tar.gz
    cd lowdown-*/
    ./configure
    # Comment out problematic BSD make conditionals for GNU make compatibility
    sed -i 's/^\.ifdef SANDBOX_INIT_ERROR_IGNORE/#.ifdef SANDBOX_INIT_ERROR_IGNORE/' Makefile
    sed -i 's/^\.if \$(SANDBOX_INIT_ERROR_IGNORE) == "always"/#.if $(SANDBOX_INIT_ERROR_IGNORE) == "always"/' Makefile
    sed -i 's/^CFLAGS.*DSANDBOX_INIT_ERROR_IGNORE=2/#CFLAGS += -DSANDBOX_INIT_ERROR_IGNORE=2/' Makefile
    sed -i 's/^\.else/#.else/' Makefile
    sed -i 's/^CFLAGS.*DSANDBOX_INIT_ERROR_IGNORE=1/#CFLAGS += -DSANDBOX_INIT_ERROR_IGNORE=1/' Makefile
    sed -i 's/^\.endif/#.endif/' Makefile
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
        
        # Try lowdown first, then markdown command
        if command -v lowdown > /dev/null 2>&1; then
            lowdown "$md_file" >> "$html_file"
        elif command -v markdown > /dev/null 2>&1; then
            markdown "$md_file" >> "$html_file"
        else
            echo "No markdown processor found!" >&2
            exit 1
        fi
        
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
cp -r ../statics output/

# copy to public directory
rm -rf ../public
cp -r ./output ../public
