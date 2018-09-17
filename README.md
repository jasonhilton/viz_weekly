---
title: "Visualising weekly mortality data using polar graphs."
author: "Jason Hilton"
date: "16 September 2018"
output:
  html_document:
    keep_md: TRUE
---

# Visualising weekly mortality data using polar graphs

Code for the Paper "Visualising Weekly Mortality Data using Polar Graphs

The paper itself is available [here](https://jasonhilton.github.io/viz_weekly/paper/Viz_weekly.html).

This repo provides the code needed for producing the paper.

The repository is designed so that the results can be reproduced by running a
series of R scripts.

# Prerequisites
The following code chunk gives all the R packages used in this analysis.


```r
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
install.packages(bookdown)
install.packages(splines)
install.packages(viridis)
install.packages(broom)
install.packages(rmarkdown)
install.packages(knitr)
install.packages(xts)
install.packages(dygraphs)
install.packages(shiny)
```


# Date acquisition
To get the data used in the analysis, you need to run an R script that downloads various files from the UK Office of National Statistics website and from the Human Mortality Database (HMD). 
To obtain the Human Mortality Database files you need to have a HMD username and password.
If you want to run be able to run the relevant script from the command line, you can add the below lines to your .Renviron file to create environment variables containing your HMD username and password. You may need to create this in your home directory. I am not an expert on security, but I understand that using environment variables may not be completely secure, so do not use a password you use for anything else in this step. 


```bash
HMD_user=your_user_name
HMD_pass=your_user_name
```

Then, you can run:


```bash
cd /path/to/viz_weekly
Rscript R/data_script.R
```
from the command line to obtain the files you need, ensuring the path to this repository is correct.
Alternatively, you can run the code in the same script interactively, and enter your HMD username and password when prompted.

# Creating intermediate files

Once these files have been obtained, you can two more Rscripts which create `rds`
files containing the exposure and the death data needed to run the models described in the paper.


```bash
Rscript R/generate_exposures.R
Rscript R/death_data.R
```

# Running the model
Next, we need to run the models themselves.
This involves the below command

```bash
Rscript R/model_fitting.R
```

# Producing the paper
Finally, the final `pdf` and `html` papers need to be produced.
Thanks to `bookdown`, this can be done pretty easily be execuating the command below.


```bash

Rscript paper/process_md.R

```


# Session info


```r
library(curl)
library(dplyr)
```

```
## 
## Attaching package: 'dplyr'
```

```
## The following objects are masked from 'package:stats':
## 
##     filter, lag
```

```
## The following objects are masked from 'package:base':
## 
##     intersect, setdiff, setequal, union
```

```r
library(tidyr)
library(ggplot2)
library(magrittr)
```

```
## 
## Attaching package: 'magrittr'
```

```
## The following object is masked from 'package:tidyr':
## 
##     extract
```

```r
library(readxl)
library(purrr)
```

```
## 
## Attaching package: 'purrr'
```

```
## The following object is masked from 'package:magrittr':
## 
##     set_names
```

```r
library(ggfan)
library(bookdown)
library(httr)
```

```
## 
## Attaching package: 'httr'
```

```
## The following object is masked from 'package:curl':
## 
##     handle_reset
```

```r
library(HMDHFDplus)
library(lubridate)
```

```
## 
## Attaching package: 'lubridate'
```

```
## The following object is masked from 'package:base':
## 
##     date
```

```r
library(timeDate)
library(rstan)
```

```
## Loading required package: StanHeaders
```

```
## rstan (Version 2.17.3, GitRev: 2e1f913d3ca3)
```

```
## For execution on a local, multicore CPU with excess RAM we recommend calling
## options(mc.cores = parallel::detectCores()).
## To avoid recompilation of unchanged Stan programs, we recommend calling
## rstan_options(auto_write = TRUE)
```

```
## 
## Attaching package: 'rstan'
```

```
## The following object is masked from 'package:magrittr':
## 
##     extract
```

```
## The following object is masked from 'package:tidyr':
## 
##     extract
```

```r
library(splines)
library(viridis)
```

```
## Loading required package: viridisLite
```

```r
library(broom)
library(rmarkdown)
library(knitr)
library(xts)
```

```
## Loading required package: zoo
```

```
## 
## Attaching package: 'zoo'
```

```
## The following objects are masked from 'package:base':
## 
##     as.Date, as.Date.numeric
```

```
## 
## Attaching package: 'xts'
```

```
## The following objects are masked from 'package:dplyr':
## 
##     first, last
```

```r
library(dygraphs)
library(shiny)
devtools::session_info()
```

```
## Session info -------------------------------------------------------------
```

```
##  setting  value                       
##  version  R version 3.5.1 (2018-07-02)
##  system   x86_64, linux-gnu           
##  ui       X11                         
##  language en_GB:en                    
##  collate  en_GB.UTF-8                 
##  tz       Europe/London               
##  date     2018-09-17
```

```
## Packages -----------------------------------------------------------------
```

```
##  package     * version   date       source         
##  assertthat    0.2.0     2017-04-11 CRAN (R 3.5.0) 
##  backports     1.1.2     2017-12-13 CRAN (R 3.5.0) 
##  base        * 3.5.1     2018-07-03 local          
##  bindr         0.1.1     2018-03-13 CRAN (R 3.5.0) 
##  bindrcpp      0.2.2     2018-03-29 CRAN (R 3.5.0) 
##  bitops        1.0-6     2013-08-17 cran (@1.0-6)  
##  bookdown    * 0.7       2018-02-18 CRAN (R 3.5.1) 
##  broom       * 0.5.0     2018-07-17 CRAN (R 3.5.1) 
##  cellranger    1.1.0     2016-07-27 CRAN (R 3.5.0) 
##  colorspace    1.3-2     2016-12-14 CRAN (R 3.5.0) 
##  compiler      3.5.1     2018-07-03 local          
##  crayon        1.3.4     2017-09-16 CRAN (R 3.5.0) 
##  curl        * 3.2       2018-03-28 CRAN (R 3.5.1) 
##  datasets    * 3.5.1     2018-07-03 local          
##  devtools      1.13.6    2018-06-27 CRAN (R 3.5.1) 
##  digest        0.6.16    2018-08-22 CRAN (R 3.5.1) 
##  dplyr       * 0.7.6     2018-06-29 CRAN (R 3.5.1) 
##  dygraphs    * 1.1.1.6   2018-07-11 CRAN (R 3.5.1) 
##  evaluate      0.11      2018-07-17 CRAN (R 3.5.1) 
##  ggfan       * 0.1.2     2018-06-14 CRAN (R 3.5.0) 
##  ggplot2     * 3.0.0     2018-07-03 cran (@3.0.0)  
##  glue          1.3.0     2018-07-17 cran (@1.3.0)  
##  graphics    * 3.5.1     2018-07-03 local          
##  grDevices   * 3.5.1     2018-07-03 local          
##  grid          3.5.1     2018-07-03 local          
##  gridExtra     2.3       2017-09-09 CRAN (R 3.5.0) 
##  gtable        0.2.0     2016-02-26 CRAN (R 3.5.0) 
##  HMDHFDplus  * 1.9.1     2018-08-09 CRAN (R 3.5.1) 
##  htmltools     0.3.6     2017-04-28 CRAN (R 3.5.0) 
##  htmlwidgets   1.2       2018-04-19 CRAN (R 3.5.1) 
##  httpuv        1.4.5     2018-07-19 CRAN (R 3.5.1) 
##  httr        * 1.3.1     2017-08-20 CRAN (R 3.5.1) 
##  inline        0.3.15    2018-05-18 CRAN (R 3.5.0) 
##  knitr       * 1.20      2018-02-20 CRAN (R 3.5.0) 
##  later         0.7.3     2018-06-08 CRAN (R 3.5.1) 
##  lattice       0.20-35   2017-03-25 CRAN (R 3.5.0) 
##  lazyeval      0.2.1     2017-10-29 CRAN (R 3.5.0) 
##  lubridate   * 1.7.4     2018-04-11 CRAN (R 3.5.0) 
##  magrittr    * 1.5       2014-11-22 CRAN (R 3.5.0) 
##  memoise       1.1.0     2017-04-21 CRAN (R 3.5.0) 
##  methods     * 3.5.1     2018-07-03 local          
##  mime          0.5       2016-07-07 CRAN (R 3.5.0) 
##  munsell       0.5.0     2018-06-12 CRAN (R 3.5.0) 
##  nlme          3.1-137   2018-04-07 CRAN (R 3.5.0) 
##  pillar        1.3.0     2018-07-14 CRAN (R 3.5.1) 
##  pkgconfig     2.0.2     2018-08-16 CRAN (R 3.5.1) 
##  plyr          1.8.4     2016-06-08 CRAN (R 3.5.0) 
##  promises      1.0.1     2018-04-13 CRAN (R 3.5.1) 
##  purrr       * 0.2.5     2018-05-29 CRAN (R 3.5.0) 
##  R6            2.2.2     2017-06-17 CRAN (R 3.5.0) 
##  Rcpp          0.12.18   2018-07-23 cran (@0.12.18)
##  RCurl         1.95-4.11 2018-07-15 CRAN (R 3.5.1) 
##  readxl      * 1.1.0     2018-04-20 CRAN (R 3.5.0) 
##  rlang         0.2.2     2018-08-16 CRAN (R 3.5.1) 
##  rmarkdown   * 1.10      2018-06-11 CRAN (R 3.5.0) 
##  rprojroot     1.3-2     2018-01-03 CRAN (R 3.5.0) 
##  rstan       * 2.17.3    2018-01-20 CRAN (R 3.5.1) 
##  scales        1.0.0     2018-08-09 CRAN (R 3.5.1) 
##  shiny       * 1.1.0     2018-05-17 CRAN (R 3.5.1) 
##  splines     * 3.5.1     2018-07-03 local          
##  StanHeaders * 2.17.2    2018-01-20 CRAN (R 3.5.0) 
##  stats       * 3.5.1     2018-07-03 local          
##  stats4        3.5.1     2018-07-03 local          
##  stringi       1.2.4     2018-07-20 cran (@1.2.4)  
##  stringr       1.3.1     2018-05-10 CRAN (R 3.5.0) 
##  tibble        1.4.2     2018-01-22 CRAN (R 3.5.0) 
##  tidyr       * 0.8.1     2018-05-18 CRAN (R 3.5.0) 
##  tidyselect    0.2.4     2018-02-26 CRAN (R 3.5.0) 
##  timeDate    * 3043.102  2018-02-21 CRAN (R 3.5.0) 
##  tools         3.5.1     2018-07-03 local          
##  utils       * 3.5.1     2018-07-03 local          
##  viridis     * 0.5.1     2018-03-29 CRAN (R 3.5.0) 
##  viridisLite * 0.3.0     2018-02-01 CRAN (R 3.5.0) 
##  withr         2.1.2     2018-03-15 CRAN (R 3.5.0) 
##  xfun          0.3       2018-07-06 CRAN (R 3.5.1) 
##  XML           3.98-1.16 2018-08-19 CRAN (R 3.5.1) 
##  xtable        1.8-3     2018-08-29 CRAN (R 3.5.1) 
##  xts         * 0.11-0    2018-07-16 CRAN (R 3.5.1) 
##  yaml          2.2.0     2018-07-25 CRAN (R 3.5.1) 
##  zoo         * 1.8-3     2018-07-16 CRAN (R 3.5.1)
```


