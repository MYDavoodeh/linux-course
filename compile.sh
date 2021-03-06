#!/bin/sh
# TODO write a proper description

# Dependency check
printf "\
    xelatex
    biber
    find
    pygmentize
" | {
    while read -r cmd; do command -v "$cmd" >/dev/null || { echo "$cmd is required!" && depneeded="depRequired"; }; done
    [ -n "$depneeded" ] && exit 1 || exit 0
} || exit 1

# -----
# BEGIN Header code
# -----
# Config (not available via input)
header="header.tex"
log="compile.log"
helpmsg="" # TODO Write a help message
notesln="5"
# Default values
destd="build"
slidesd="src"
notesd="$destd/notes"
debug="withoutDebug"
biber="withBiber"
# notes="only notes"
keep="removeAuxFiles"
dont="false" && ref="withoutNotes"
filepattern="*"

checkin() { # Checks paramater and respond. $2 is the flag and $1 is value.
    # shellcheck disable=SC2015
    [ -n "$1" ] && return 0 || { [ -n "$2" ] && echo "No parameter for $2" || echo "Bad inputs! Seek help."; }
}

cleanup() { # Remove auto-generated files
    rm -rdf _minted*
    find . -maxdepth 1 -type f -regextype gnu-awk -regex "^.*\\.(4tc|xref|tmp|pyc|pyo|fls|vrb|fdb_latexmk|bak|swp|aux|log|synctex\\(busy\\)|lof|lot|maf|idx|mtc|mtc0|nav|out|snm|toc|bcf|run\\.xml|synctex\\.gz|blg|bbl)" \
        -delete
    echo "removed auxilary files"
}

compile() { xelatex -shell-escape "$1" >>$log; }

compileto() { # $1: Destination folder for pdf; $2: file; $3: withBiber?; $4: if present it will be set as a beamer show option
    [ -n "$4" ] && sed -i "${notesln}i\\\\\\setbeameroption{show $4}" "$header" # makes Beamer to export "only notes"
    find . -name "$2*.tex" \
        ! -name 'header*.tex' \
        -print | while IFS= read -r file; do
        compile "$file"
        [ "$3" = "withBiber" ] && {
            biber "${file%.tex}" >>$log
            echo "bibed $file"
        }
        compile "$file"
        echo "compiled $file"
    done
    # Move PDFs to the target folder
    mkdir "../$1" -p >/dev/null 2>&1
    # shellcheck disable=SC2035
    mv -v *.pdf "../$1"
    echo "moved pdfs to $1"
    [ -n "$4" ] && sed -i "${notesln}d" "$header" # removes "only notes" marker from slides headers
}

mvpdf() { # $1: label; $2(opt): destination; $3(opt): source;
    mkdir -p "${2:-build}" >/dev/null 2>&1
    for file in ${3:-build}/*.pdf; do
        mv -v "$file" "${2:-build}/$(basename -- "$file" | sed 's/\.pdf$//')_$1.pdf"
    done
}

publish() {
    mkdir -v build
    dir="build/full$(git rev-parse --short=7 HEAD 2>&1 | grep -Pq '^([a-f]|\d){7}$' && echo "-$(git rev-parse --short=7 HEAD)")"
    rm -rdfv $dir
    "$(basename -- "$0")" --notes --biber --full-references >/dev/null 2>&1
    mvpdf full-references $dir
    mvpdf notes $dir build/notes
    rm -d build/notes >/dev/null 2>&1
    "$(basename -- "$0")" --biber --original-refs >/dev/null 2>&1
    mvpdf original-references $dir
    "$(basename -- "$0")" --biber --full-references --second-screen >/dev/null 2>&1
    mvpdf second-screen $dir
    echo "published in $dir"
}

# Inputs and flag management
[ -n "$1" ] && { printf "%s" "$1" | grep -q "^-" || { filepattern="$1" && shift; }; } #If the first input wasn't a flag read it as the $file pattern
while true; do
    case "$1" in
        -i | --input) checkin "$2" "$1" && filepattern="${2%.tex}" && shift 2 ;;
        -f | --full-references) ref="withNotes" && dont="true" && shift ;;
        -d | --debug) debug="withDebug" && shift ;;
        -b | --biber) biber="withBiber" && shift ;;
        -l | --disable-biber) biber="withoutBiber" && shift ;;
        -z | --original-refs) ref="withoutNotes" && shift ;;
        -n | --notes) notes="only notes" && shift ;;
        -w | --second-screen) notes="notes on second screen" && dont="true" && shift ;;
        -o | --only-notes) notes="only notes" && dont="true" && shift ;;
        -c | --destination-dir) checkin "$2" "$1" && destd="$2" && shift 2 ;;
        -s | --slides-dir) checkin "$2" "$1" && slidesd="$2" && shift 2 ;;
        -y | --notesd-dir) checkin "$2" "$1" && notesd="$2" && shift 2 ;;
        -k | --keep) keep="keepAuxFiles" && shift ;;
        -r | --clean) keep="removeAuxFiles" && shift ;;
        -q | --quite) debug="withoutDebug" && shift ;;
        -p | --purge) purged="${2:-.}" && shift ;;
        -h | --help) echo "$helpmsg" && exit 0 ;;
        -a | --publish)
            publish
            exit 0
            ;;
        -*) echo "Invalid option: $1" && echo "$helpmsg" && exit 1 ;;
        *) break ;; # No more options
    esac
done
# -----
# END Header code
# -----

[ -n "$purged" ] && cd "$purged" && cleanup && exit 0
cd "$slidesd" || exit 1
rm $log
[ "$dont" = "true" ] || compileto "$destd/" "$filepattern" "$biber"
[ "$notes" = "notes on second screen" ] && notesd="$destd"
[ -n "$notes" ] && compileto "$notesd/" "$filepattern" "$biber" "$notes"
# When notes are on the second screen, note references are automatically included in References section
[ "$ref" = "withNotes" ] && [ "$notes" != "notes on second screen" ] && { # Include note references in the final build
    # Compile and notes and save the bib file then use it to compile the main file
    { [ -n "$notes" ] && [ "$biber" = "withBiber" ]; } || compileto "trash/" "$filepattern" "withBiber" "only notes"
    echo "made temporary note references files"
    echo "compiling with new .bbl files"
    compileto "$destd/" "$filepattern" "withoutBiber"
    rm -rd ../trash && echo "removed directory 'trash'"
    keep="removeAuxFiles"
}
[ "$debug" = "withDebug" ] && cat $log
[ "$keep" != "keepAuxFiles" ] && cleanup
exit 0
