library(knitr)
library(rmarkdown)


rmarkdown::render("paper/Viz_weekly.Rmd",
                  output_format = bookdown::html_document2(
                    number_sections=T,
                    fig_caption=T,
                    css="viz.css",
                    keep_md=T)
                  )
rmarkdown::render("paper/Viz_weekly.Rmd",
                  output_format = bookdown::pdf_document2(
                    number_sections=T,
                    fig_caption=T,
                    keep_tex=T)
)
