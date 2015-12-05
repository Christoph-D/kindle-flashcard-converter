#!/bin/bash

set -eu

if [[ ! -x "$(which sqlite3)" ]]; then
   echo "Error: Please install sqlite3."
   exit 1
fi

if [[ ! -d "${JAPANESE_TOOLS-}" ]]; then
    echo 'Please set $JAPANESE_TOOLS to a working copy of https://github.com/Christoph-D/Japanese-Tools.'
    exit 1
fi

if [[ ($# -ne 1 && $# -ne 2) || ! -s "$1" ]]; then
    echo 'Please provide a path to the flash card database and optionally a path to a dictionary file to be used with eb.'
    echo 'The flash card database is located at system/vocabulary/vocab.db on your kindle.'
    echo 'Please make sure that eb from https://github.com/Christoph-D/Tools is in your PATH.'
    exit 1
fi

database="$1"

sql() {
    sqlite3 -list -separator □ "$database" "$1"
}

dictionary_exec=
if [[ -e "$(which eb)" && $# -eq 2 && -d "$2" ]]; then
    dictionary_exec="eb"
    dictionary_file="$2"
fi

read_exec="$JAPANESE_TOOLS/reading/read.py"

while IFS=□ read -r word stem usage tag; do
    # Make the word safe for sed.
    word=${word//[;/.\\]/}
    # Trim whitespace and perform cloze deletion.
    cloze="$(printf '%s' "$usage" | sed 's/[　 ]*$//;s/'"$word"'/{{c1::'"$word"'}}/')"
    if [[ -z $cloze ]]; then
        printf 'Warning: Found no sentence for %s\n' "$word" >&2
        continue
    fi
    reading="$("$read_exec" "$usage")"
    if [[ -n $dictionary_exec ]]; then
        # Skip the first line of the dictionary lookup because it
        # likely contains the word itself.
        lookup="$($dictionary_exec "$dictionary_file" "$word" | tail -n +2)"
        # Merge all lines with <br>
        lookup="${lookup//$'\n'/<br>}"
        printf '"%s","%s","%s","%s"\n' "$cloze" "$reading" "$tag" "$lookup"
    else
        printf '"%s","%s","%s"\n' "$cloze" "$reading" "$tag"
    fi
done < <(sql "
SELECT
  w.word,
  w.stem,
  l.usage,
  b.title
FROM WORDS w
LEFT JOIN LOOKUPS l
  ON w.id = l.word_key
LEFT JOIN BOOK_INFO b
  ON l.book_key = b.guid
GROUP BY w.word
")
