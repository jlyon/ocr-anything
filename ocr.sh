#!/bin/sh

# Holds the help information displayed when the -h flag is added
usage="
ocr-anything
============

Convert (almost) any file to text, including all PDFs, images, doc files and more. 
Just send the file and this script will do the rest, including analyizing the mimetype,
and converting it to text with an OCR program (tesserect), or converting it with 
LibreOffice.

./ocr.sh -f\"my file.pdf\" -p5 -d72


OPTIONS
    -h
        Show a summary of options

    -f
        Required. The file to lexile.
        
    -p
        The maximum amount pages to OCR.  This only has an effect if the document 
        contains an image (scan) that needs to be OCRed. Defaults to 10000.

    -d
        The DPI to use when OCRing the file.  This only has an effect if the document 
        contains an image (scan) that needs to be OCRed. Defaults to 300.


RETURN
    This script will print a JSON array to the screen containing:
    {
        text: <THE_TEXT_OUTPUT_OF_THE_DOC>,
        mimetype: application/pdf|application/msword|...,
        utility: convert|pdftotext|ocr,
        pages: <NUMBER_OF_PAGES>
    }
"

# Settings and default options
FILE="$1"
DPI=300
MAXPAGES=10000
TMP="/tmp/ocr-${RANDOM}"
PAGES=1

# Get the arguments
while getopts "f:p:d:h" option; do
  case "${option}" in
    f) FILE=${OPTARG};;
    p) MAXPAGES=${OPTARG};;
    d) DPI=${OPTARG};;
    h) echo "$usage"; exit 2;;
  esac
done


# Look at mimetype to figure out what type of file this is
#MIMETYPE=`file --mime-type "$FILE"`
#MIMETYPE=`echo $MIMETYPE| cut -d':' -f 2`
#MIMETYPE="${MIMETYPE:1}"
# We now use xdg-mime to calculate the mimetype becuase of errors with file --mime-type
# when the file contained spaces. From http://askubuntu.com/questions/103594/how-do-i-determine-the-mime-type-of-a-file
MIMETYPE=`xdg-mime query filetype "$FILE"`

# PDF File, check if it has embedded fonts (if it is not OCRed)
if [ $MIMETYPE == 'text/plain' ]; then

  TEXT=`cat "${FILE}"`
  TOOL="text"

elif [ $MIMETYPE == 'application/pdf' ]; then

  FONTS=`pdffonts "$FILE"`

  # Text is embedded in the PDF
  if [[ "$FONTS" == *TrueType* ]]; then

    pdftotext "$FILE" "${TMP}.txt"
    TEXT=`tr -cd "[:print:]" "${TMP}.txt"`
    TOOL="pdftotext"

  # Use Tesseract to OCR the file
  else

    mkdir "$TMP"
    #convert -density $DPI -depth 8 -alpha Off "$FILE" "${TMP_DIR}/page_%d.tif"

    pdftk "$FILE" burst dont_ask output "${TMP}/%03d.pdf" &> /dev/null
    dir="${TMP}/*.pdf"  # for some reason, we need to put this in its own variable
    PAGES=0
    for f in $dir ; do
      PAGES=$(( $PAGES + 1 ))
      if [ $PAGES -le $MAXPAGES ]; then
        f=`basename $f .pdf`
        convert -density $DPI -depth 8 -alpha Off "${TMP}/${f}.pdf" "${TMP}/${f}.tif" &> /dev/null
        tesseract "${TMP}/${f}.tif" "${TMP}/$f" &> /dev/null
        cat "${TMP}/${f}.txt" >> "${TMP}/result.txt"
      fi
    done

    #TEXT=`tr -d "[:print:]" "${TMP}/result.txt"`
    TEXT=`cat "${TMP}/result.txt"`
    TOOL="ocr"

  fi

# OCR a single image
elif [[ $MIMETYPE == image/* ]]; then

  mkdir "$TMP"
  echo $FILE
  tesseract "$FILE" "${TMP}/result.txt" &> /dev/null
  TEXT=`tr -cd "[:print:]" "${TMP}/result.txt"`
  TOOL="ocr"

# Use libreoffice to do the conversion
elif
  #[ $MIMETYPE == 'application/msword' ] ||
  [ $MIMETYPE == 'application/vnd.ms-word' ] ||
  [ $MIMETYPE == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ] ||
  [ $MIMETYPE == 'application/vnd.oasis.opendocument.text' ] ||
  [ $MIMETYPE == 'text/html' ]
then

  # This is wrapped in a while loop because only one instance of soffice can run at
  # a time, so the file may not get generated the first time around.  This is basically
  # a poor man's way of calling office as a webservice.
  i=0
  while [ $i -le 10 ]; do
    # Txt file is actually at $TMP/basename
    BASENAME=`basename "$FILE"`
    BASENAME="${BASENAME%.*}"
    if [ $i -gt 0 ]; then
      sleep 1
    fi
    if [ -f "${TMP}/${BASENAME}.txt" ]; then
      i=100
    else
      i=$(( $i + 1 ))
      soffice --headless --convert-to txt:Text --outdir "$TMP" "$FILE" &> /dev/null
    fi
  done

  TOOL="convert"
  TEXT=`tr -cd "[:print:]" < "${TMP}/${BASENAME}.txt"` &> /dev/null
fi

# Escape for JSON: http://stackoverflow.com/questions/10053678/escaping-characters-in-bash-for-json
TEXT=${TEXT//\\/\\\\} # \
TEXT=${TEXT//\//\\\/} # /
#TEXT=${TEXT//\'/\\\'} # ' (not strictly needed ?)
TEXT=${TEXT//\"/\\\"} # "
TEXT=${TEXT//	/\\t} # \t (tab)
TEXT=${TEXT//
/\\\n} # \n (newline)
TEXT=${TEXT//^M/\\\r} # \r (carriage return)
TEXT=${TEXT//^L/\\\f} # \f (form feed)
TEXT=${TEXT//^H/\\\b} # \b (backspace)

# return JSON array
echo "{ \"text\": \"${TEXT}\", \"mimetype\": \"${MIMETYPE}\", \"utility\": \"${TOOL}\", \"pages\": ${PAGES} }"

# delete the tmp files (and return nothing)
#rm -fr $TMP &> /dev/null;

