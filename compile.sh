#!/bin/sh
# A short script for taking "production" exports from everything
# Inputs: if you don't specify a file (/file pattern) you can start from $2
# $1(opt): file; $2(opt): withBiber?; $3(opt): withNotes?; $4(opt): withDebug?;
# Examples (providing that your slide.tex files are in ./src/):
# ./compile.sh withBiber withoutNotes
# ./compile.sh intro withBiber
# ./compile.sh section_* withoutBiber withNotes withoutDebug

slidesd="src"
destd="build"
header="header.tex"
log="compile.log"


compile(){ xelatex -shell-escape "$1" >> $log ;}

removeext(){ echo "$1" | sed 's/\.tex$//' ;}

compileto(){ # $1: Destination folder for pdf; $2(opt): file; $3(opt): withBiber?;
    pattern="$2.tex"
    find .\
        -name "$pattern"\
        ! -name 'header.tex'\
        -print | while IFS= read -r file; do
            compile "$file"
            [ "$3" = "withBiber" ] && {
                biber "$(removeext "$file")" >> $log
                echo "bibed $file"
            }
            compile "$file"
            echo "compiled $file"
        done

    # Move PDFs to the target folder
    mkdir "../$1" >/dev/null 2>&1
    # shellcheck disable=SC2035
    mv -v *.pdf "../$1"
    echo "moved pdfs to $1"
}


cd "$slidesd" || exit 1
if [ "$1" = "withBiber" ] ;then
    compileto "$destd/" '*' "$1"
else
    compileto "$destd/" "$(removeext "$1")" "$2"
    shift
fi
# BEAMER ONLY: Prepare to only compile notes
[ "$2" = "withNotes" ] && {
    sed -i '2i\\\\setbeameroption{show only notes}' "$header" # makes Beamer to export "only notes"
    compileto "$destd/notes/"
    sed -i '2d' "$header" # removes "only notes" marker from slides headers
}
[ "$3" = "withDebug" ] && cat $log
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
    -exec rm -f {} +
echo "removed auxilary files"
