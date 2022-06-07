all: readme data

data:
	R CMD BATCH --no-restore --no-save code/jung-lvl1-habitat-data.R
	R CMD BATCH --no-restore --no-save code/jung-lvl2-habitat-data.R

clean:
	rm -f results/*.tif

readme:
	R --slave -e "rmarkdown::render('README.Rmd')"

.PHONY: all data readme
