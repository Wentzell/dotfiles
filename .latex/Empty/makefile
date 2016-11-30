default: main.pdf
	
main.pdf: main.tex content/*.tex
	rubber -f --pdf -s main.tex
	rubber-info --check main.pdf

clean:
	rm -rf *.aux *.bbl *.blg *.log *.pdf *.toc *.snm *.out *.nav *.toc *.tps *.maf *.mtc *.mtc0 *.fls *.fdb_latexmk *.dvi *.synctex.gz

.PHONY: clean
