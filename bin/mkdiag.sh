#!/usr/bin/env sh

rm *.pdf
rubber -m pdftex $@
fname=$(basename $@ .tex)
ls *.mp | xargs mpost
rm $fname.pdf
rubber -m pdftex $@
pdfcrop $fname.pdf $fname.pdf
mupdf $fname.pdf
convert -density 1000 $fname.pdf $fname.png
