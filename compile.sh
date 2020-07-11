#!/bin/sh
# TODO write a proper description

# -----
# BEGIN Header code
# -----
# Config (not available via input)
header="header.tex"
log="compile.log"
helpmsg="" # TODO Write a help message
notesln="4"
# Default values
destd="build"
slidesd="src"
notesd="$destd/notes"
debug="withoutDebug"
biber="withoutBiber"
notes="withoutNotes"
keep="keepAuxFiles"
filepattern="*"


checkin(){ # Checks paramater and respond. $2 is the flag and $1 is value.
    # shellcheck disable=SC2015
    [ -n "$1" ] && return 0 || { [ -n "$2" ] && error "No parameter for $2" || error "Bad inputs! Seek help." ;}
}

removeext(){ echo "$1" | sed 's/\.tex$//' ;}

cleanup(){ # Remove auto-generated files
    find . -maxdepth 1 -type f\
        ! -name '*.tex'\
        ! -name '*.sh'\
        ! -name '*.bib'\
        ! -name '*.org'\
        ! -name '*.md'\
        ! -name '.gitignore'\
        ! -name '.editorconfig'\
        ! -name 'README'\
        ! -name 'LICENSE'\
        -exec rm -f {} +
    echo "removed auxilary files"
}

compile(){ xelatex -shell-escape "$1" >> $log ;}

compileto(){ # $1: Destination folder for pdf; $2(opt): file; $3(opt): withBiber?;
    pattern="$2.tex"
    find .\
        -name "$pattern"\
        ! -name 'header*.tex'\
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

compilenotes(){ # BEAMER ONLY: Prepare to only compile notes
    sed -i "${notesln}i\\\\\\setbeameroption{show only notes}" "$header" # makes Beamer to export "only notes"
    compileto "$1" "$2" "$3"
    sed -i "${notesln}d" "$header" # removes "only notes" marker from slides headers
}


# Inputs and flag management
[ -n "$1" ] && { echo "$1" | grep -q "^-" || { input=$1 && shift ;} ;} #If the first input wasn't a flag read it as the $file pattern
while true; do
    case "$1" in
        -f | --file | -i | --input) checkin "$2" "$1" && filepattern="$(removeext "$2")" && shift 2 ;;
        -d | --debug) debug="withDebug" && shift ;;
        -b | --biber) biber="withBiber" && shift ;;
        -n | --notes) notes="withNotes" && shift ;;
        -o | --only-notes) notes="onlyNotes" && shift ;;
        -c | --destination-dir) checkin "$2" "$1" && destd="$2" && shift 2 ;;
        -s | --slides-dir) checkin "$2" "$1" && slidesd="$2" && shift 2 ;;
        -y | --notesd-dir) checkin "$2" "$1" && notesd="$2" && shift 2 ;;
        -k | --keep) keep="keepAuxFiles" && shift ;;
        -r | --clean) keep="removeAuxFiles" && shift ;;
        -q | --quite) debug="withoutDebug" && shift ;;
        -p | --purge) purge="purgeHere" && shift ;;
        -h | --help) echo "$helpmsg" && exit 0 ;;
        -*) echo "Invalid option: $1" && echo "$helpmsg" && exit 1 ;;
        *)  break ;; # No more options
    esac
done
# -----
# END Header code
# -----


[ "$purge" = "purgeHere" ] && cleanup && exit 0
cd "$slidesd" || exit 1
rm $log
[ "$notes" = "onlyNotes" ] || compileto "$destd/" "$filepattern" "$biber"
[ "$notes" != "withoutNotes" ] && compilenotes "$notesd/" "$filepattern" "$biber"
[ "$debug" = "withDebug" ] && cat $log
[ "$keep" != "keepAuxFiles" ] && cleanup
exit 0
