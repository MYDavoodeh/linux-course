#!/bin/sh
# A short script for taking "production" exports from everything

# If the value of mode is anything other than "withoutBiber" compilation will be signifcantly slower
mode="${1:-withoutBiber}"

slidesd="slides"

ccmd(){ xelatex -shell-escape "$1"; }

compileto(){
# Compile
for file in "$slidesd"/*.tex ;do
    ccmd "$file"
    [ "$2" = "withBiber" ] && {
        biber "$file"
        ccmd "$file"
    }
    ccmd "$file"
done

# Move PDFs to the target folder
mkdir "$1" >/dev/null 2>&1
mv ./*.pdf "$1"

# Remove auto-generated files
find . -maxdepth 1 -type f\
    ! -name '*.tex'\
    ! -name '*.sh'\
    ! -name '*.bib'\
    ! -name '*.org'\
    ! -name '*.md'\
    ! -name '.gitignore'\
    ! -name 'README'\
    ! -name 'LICENSE'\
    -exec rm -fv {} +

# Remove auto-generated files from the target folder as well
(cd "$slidesd" || exit
find . -maxdepth 1 -type f\
    ! -name '*.tex'\
    -exec rm -fv {} +)
}

[ "$mode" = "withoutBiber" ] && compileto pdfs/ || {
    compileto pdfs/ withBiber
    # BEAMER ONLY: Prepare to only compile notes
    sed -i '2i\\\\setbeameroption{show only notes}' "header.tex" # makes Beamer to export "only notes"
    compileto notes/
    sed -i '2d' header.tex # removes "only notes" marker from slides headers
}
