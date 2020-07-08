#!/bin/sh
# A short script for taking "production" exports from everything
# $1(opt): withBiber? OR file; $2(opt): withBiber? OR withNotes? $3(opt): withNotes?
# Examples (providing that your slide.tex files are in ./src/):
# ./compile.sh withBiber withoutNotes
# ./compile.sh intro withBiber
# ./compile.sh section_* withoutBiber withNotes

# If the value of mode is anything other than "withoutBiber" compilation will be signifcantly slower
arg="${1:-withoutBiber}"

slidesd="src"
destd="build"
header="header.tex"
debug="withoutDebug" #| enable state is "withDebug"
log="compile.log"

cd "$slidesd"

# Call this after exporting output of a command to $log file
debug(){ [ "$debug" = "withDebug" ] && cat $log ; rm $log ;}

compilenotes(){
    sed -i '2i\\\\setbeameroption{show only notes}' "$header" # makes Beamer to export "only notes"
    compileto "$destd/notes/"
    sed -i '2d' "$header" # removes "only notes" marker from slides headers
}

compile(){ xelatex -shell-escape "$1" > $log ; debug ;}

removeext(){ sed 's/\.tex$//' <<< "$1" ;}

compileto(){ # $1: Destination folder for pdf; $2(opt): file; $3(opt): withBiber?;
    pattern="${2:-*}.tex"
    find .\
        -name "$pattern"\
        ! -name 'header.tex'\
        -print0 | while IFS= read -r -d '' file; do
            compile "$file"
            [ "$3" = "withBiber" ] && {
                biber "$(removeext "$file")" > $log ; debug
                echo "bibed $file"
            }
            compile "$file"
            echo "compiled $file"
        done

    # Move PDFs to the target folder
    mkdir "../$1" >/dev/null 2>&1
    mv -v *.pdf "../$1"
    echo "moved pdfs to $1"

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
}


if [ "$arg" = "withoutBiber" ] ;then
    compileto "$destd/"
elif [ "$arg" = "withBiber" ] ;then
    compileto "$destd/" '*' withBiber
    [ "$2" = "withNotes" ] && compilenotes # BEAMER ONLY: Prepare to only compile notes
else
    compileto "$destd/" "$(removeext "$file")" "$2"
    [ "$2" = "withNotes" ] && compilenotes # BEAMER ONLY: Prepare to only compile notes
fi
