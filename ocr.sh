#!/bin/bash

# Takes in any file, and returns a JSON array:
# {
#   text: <THE_TEXT_OUTPUT_OF_THE_DOC>
#   mimetype: application/pdf|application/msword|...
#   utility: convert|pdftotext|ocr
#   pages: <NUMBER_OF_PAGES>
# }

# Settings
FILE="$1"
DPI=300

# Set up vars
TMP="/tmp/ocr-${RANDOM}"
PAGES=1

# Look at mimetype to figure out what type of file this is
MIMETYPE=`file --mime-type "$FILE"`
MIMETYPE=`echo $MIMETYPE| cut -d':' -f 2`
MIMETYPE="${MIMETYPE:1}"

# PDF File, check if it has embedded fonts (if it is not OCRed)
if [ $MIMETYPE == 'text/plain' ]; then

  TEXT=`cat "${FILE}"`
  TOOL="text"

elif [ $MIMETYPE == 'application/pdf' ]; then
  
  FONTS=`pdffonts "$FILE"`
  
  # Text is embedded in the PDF
  if [[ "$FONTS" == *TrueType* ]]; then
    
    pdftotext "$FILE" "${TMP}.txt"
    TEXT=`cat "${TMP}.txt"`
    TOOL="pdftotext"

  # Use Tesseract to OCR the file
  else
    
    mkdir "$TMP"
    #convert -density $DPI -depth 8 -alpha Off "$FILE" "${TMP_DIR}/page_%d.tif"

    pdftk "$FILE" burst dont_ask output "${TMP}/%03d.pdf" &> /dev/null
    dir="${TMP}/*.pdf"  # for some reason, we need to put this in its own variable
    PAGES=0
    for f in $dir ; do
      f=`basename $f .pdf`
      convert -density 300 -depth 8 -alpha Off "${TMP}/${f}.pdf" "${TMP}/${f}.tif" &> /dev/null
      tesseract "${TMP}/${f}.tif" "${TMP}/$f" &> /dev/null
      cat "${TMP}/${f}.txt" >> "${TMP}/result.txt"
      PAGES=$(( $PAGES + 1 ))
    done

    TEXT=`cat "${TMP}/result.txt"`
    TOOL="ocr"
  
  fi

# OCR a single image
elif [[ $MIMETYPE == image/* ]]; then

  mkdir "$TMP"
  echo $FILE
  tesseract "$FILE" "${TMP}/result.txt" &> /dev/null
  TEXT=`cat "${TMP}/result.txt"`
  TOOL="ocr"

# Use libreoffice to do the conversion
elif  
  [ $MIMETYPE == 'application/msword' ] ||
  #[ $MIMETYPE == 'application/vnd.ms-excel' ] ||
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
  TEXT=`cat "${TMP}/${BASENAME}.txt"` &> /dev/null

fi

# Escape for JSON: http://stackoverflow.com/questions/10053678/escaping-characters-in-bash-for-json
TEXT=${TEXT//\\/\\\\} # \ 
TEXT=${TEXT//\//\\\/} # / 
TEXT=${TEXT//\'/\\\'} # ' (not strictly needed ?)
TEXT=${TEXT//\"/\\\"} # " 
TEXT=${TEXT//   /\\t} # \t (tab)
TEXT=${TEXT//
/\\\n} # \n (newline)
TEXT=${TEXT//^M/\\\r} # \r (carriage return)
TEXT=${TEXT//^L/\\\f} # \f (form feed)
TEXT=${TEXT//^H/\\\b} # \b (backspace)

# return JSON array
echo "{ text: \"${TEXT}\", mimetype: \"${MIMETYPE}\", utility: \"${TOOL}\", pages: ${PAGES} }"

# delete the tmp files (and return nothing)
#rm -fr $TMP &> /dev/null;

