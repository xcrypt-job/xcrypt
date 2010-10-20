.phony: dvi ps pdf
dvi: Xcrypt_manual.dvi
ps: Xcrypt_manual.ps
pdf: Xcrypt_manual.pdf

Xcrypt_manual.dvi: Xcrypt_manual.tex
	platex -kanji=euc Xcrypt_manual.tex
	platex -kanji=euc Xcrypt_manual.tex
Xcrypt_manual.ps: Xcrypt_manual.dvi
	dvips Xcrypt_manual.dvi
Xcrypt_manual.pdf: Xcrypt_manual.dvi
	dvipdfmx Xcrypt_manual.dvi
