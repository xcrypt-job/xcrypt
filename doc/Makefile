.phony: dvi ps pdf
dvi: Xcrypt_manual.dvi Xcrypt_spec.dvi
ps:  Xcrypt_manual.ps  Xcrypt_spec.ps
pdf: Xcrypt_manual.pdf Xcrypt_spec.pdf

Xcrypt_manual.dvi: Xcrypt_manual.tex
	platex -kanji=euc Xcrypt_manual.tex
	platex -kanji=euc Xcrypt_manual.tex
Xcrypt_manual.ps: Xcrypt_manual.dvi
	dvips Xcrypt_manual.dvi
Xcrypt_manual.pdf: Xcrypt_manual.dvi
	dvipdfmx Xcrypt_manual.dvi

Xcrypt_spec.dvi: Xcrypt_spec.tex
	platex -kanji=euc Xcrypt_spec.tex
	platex -kanji=euc Xcrypt_spec.tex
Xcrypt_spec.ps: Xcrypt_spec.dvi
	dvips Xcrypt_spec.dvi
Xcrypt_spec.pdf: Xcrypt_spec.dvi
	dvipdfmx Xcrypt_spec.dvi
