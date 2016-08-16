
default: settings/header.tex 
	rubber -f --pdf -s main.tex
	rubber-info --check main.pdf

clean:
	rm -rf *.aux *.bbl *.blg *.log *.pdf *.toc *.snm *.out *.nav *.toc *.tps *.maf *.mtc *.mtc0 *.fdb_latexmk *.fls

.PHONY: clean
