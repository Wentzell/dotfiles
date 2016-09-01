#!/usr/bin/env sh

rm *.pdf
rubber -m pdftex $@
ls *.mp | xargs mpost
rm *.pdf
rubber -m pdftex $@
pdfcrop *.pdf
okular *crop.pdf
2png *crop.pdf
mv *crop.pdf.png out.png
