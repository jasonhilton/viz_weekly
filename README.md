# viz_weekly
Code for the Paper "Visualising Weekly Mortality Data using Polar Graphs

The paper itself is available at [here](https://jasonhilton.github.io/viz_weekly/paper/Viz_weekly.html).

This repo provides the code needed for producing the above paper.

The repository is designed so that the results can be reproduced by running a
series of R scripts.

# Prerequisites
The following code chunk gives all the R packages used in this analysis.

```{r}
install.packages(curl)
install.packages(dplyr)
install.packages(tidyr)
install.packages(ggplot2)
install.packages(magrittr)
install.packages(readxl)
install.packages(purrr)
install.packages(ggfan)
install.packages(httr)
install.packages(HMDHFDplus)
install.packages(lubridate)
install.packages(timeDate)
install.packages(rstan)
install.packages(splines)
install.packages(viridis)
install.packages(broom)
install.packages(rmarkdown)
install.packages(knitr)
install.packages(xts)
install.packages(dygraphs)
install.packages(shiny)
```

To produce the final html file, it is necessary to also have a working pandoc installation, and the pandoc filters `citeproc` and `fignos` installed.

# Date acquisition
To get the data used in the analysis, you need to run an R script that downloads various files from the UK Office of National Statistics website and from the Human Mortality Database (HMD). 
To obtain the Human Mortality Database files you need to have a HMD username and password.
If you want to run be able to run the relevant script from the command line, you can add the below lines to your .Renviron file to create environment variables containing your HMD username and password. You may need to create this in your home directory. I am not an expert on security, but I understand that using environment variables may not be completely secure, so do not use a password you use for anything else in this step. You can alternatively run the relevant script interactively.

```{bash}
HMD_user=your_user_name
HMD_pass=your_user_name
```

Then, you can run:

```{bash}
cd /path/to/viz_weekly
Rscript R/data_script.R
```
from the command line to obtain the files you need, ensuring the path to this repository is correct.
Alternatively, you can run the same script interactively, and enter your HMD username and password when prompted.

# Creating intermediate files

Once these files have been obtained, you can two more Rscripts which create `rds`
files containing the exposure and the death data needed to run the models described in the paper.

```{bash}
Rscript R/generate_exposures.R
Rscript R/death_data.R
```

# Running the model
Next, we need to run the models themselves.
This involves the below command
```{bash}
Rscript R/model_fitting.R
```

# Producing the paper
Finally, the final `pdf` and `html` papers need to be produced.
The `.pdf` paper can be produced using the following steps:

```{bash}
cd paper
Rscript process_md.R
pdflatex Viz_Weekly.tex
bibtex Viz_weekly
pdflatex Viz_Weekly.tex
pdflatex Viz_Weekly.tex
```

The process used `html` is more complicated. Rstudio ships with a version of pandoc that doesn't include `pandoc-fignos`, which I use to produce numbered figures, but Rstudio does seem to produce nicer default formatting than if I use an R to convert markdown to html elsewhere. I therefore evalutate the below line from within Rstudio to deactivate the Rstudio pandoc and use the system pandoc instead (the path to which should be included in your `PATH` environment variable). 

```{r}
Sys.unsetenv("RSTUDIO_PANDOC")
```

I then knit the html through the Rstudio GUI by pressing the `knit/knit to html` button with the `paper/Viz_weekly.Rmd` file in open and in focus in the editor pane. Note for this to work `pandoc` and `pandoc-fignos` must be installed separately. I will try and makes this process less fiddly.




