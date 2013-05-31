ocr-anything
============

Convert (almost) any file to text, including all PDFs, images, doc files and more. 
Just send the file and this script will do the rest, including analyizing the mimetype,
and converting it to text with an OCR program (tesserect), or converting it with 
LibreOffice.


Installing and Using
====================
First, run the `install.sh` bash script to install all of the dependencies.
   
   ```
   git clone github.com/jlyon/ocr-anything
   cd ocr-anything
   chmod +x ocr.sh
   ./ocr.sh path/to/file/name
   ```

The script by default will print a JSON string containing:
 - text : The text that was read from the file
 - mimetype : The mimetype of the file
 - utility : The utility that was used. One of: text, ocr, pdf2text, convert
 - pages : The number of pages read. 1 for everything but multi-page PDFs

