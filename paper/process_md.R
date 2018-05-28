library(knitr)
library(rmarkdown)


cmd_arg <- commandArgs(trailingOnly = T)


convertChapter<-function(chapter_name, standalone=T){
  
  # Convert from RMarkdown (.Rmd) to normal markdown (.md) using knit
  knit(paste( chapter_name, ".Rmd", sep=""),
       paste( chapter_name,".md",sep=""))
  
  pandoc_options = c("--filter", "pandoc-fignos", 
                     "--filter", "pandoc-tablenos",
                     "--filter", "pandoc-eqnos",
                     "--natbib", "-S")
  if (standalone){
    pandoc_options <- c(pandoc_options, "-s")
  }
  # Convert from markdown (.md) to latex source (.tex) using pandoc
  pandoc_convert(paste( chapter_name,".md",sep=""),
                 to = "latex", 
                 from =  "markdown+autolink_bare_uris+ascii_identifiers+tex_math_dollars",
                 options = pandoc_options,
                 output = paste(chapter_name,".tex",sep=""),
                 wd = ".")
    # pandoc_convert(paste( chapter_name,".md",sep=""),
    #              to = "html", 
    #              from =  "markdown+autolink_bare_uris+ascii_identifiers+tex_math_dollars",
    #              options = pandoc_options,
    #              output = paste(chapter_name,".html",sep=""),
    #              wd = ".")
  return(NULL)
}


convertChapter("Viz_weekly")

# do all work on chapter in .Rmd files
# convert to .md
# knit("Introduction.Rmd", "Introduction.md")
# 

# pandoc_convert command converts md to tex as follows
# pandoc ****.md -t latex -s -S --natbib --bibliography ***.bib -o Introduction.tex
# note flags:

# -s produce standalone doc! - ie for independent latex article include -s, 
#                       for thesis chapter exclude -s, produces fragment for .tex 'include'

# -S typographically smart   ie nice markdown whistles and bells.

# -t equivalent --to

# rstudio uses the below.
# --from markdown+autolink_bare_uris+ascii_identifiers+tex_math_single_backslash


#knit("../README.Rmd","../README.md")









