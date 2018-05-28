library(curl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(magrittr)
library(readxl)
library(purrr)
library(ggfan)
library(httr)
library(HMDHFDplus)


# 21st century mortality files.
# deaths by age, sex, year, and cause of death.
deaths_file <- paste0("https://www.ons.gov.uk/file?uri=",
                      "/peoplepopulationandcommunity/birthsdeathsandmarriages/deaths/",
                      "datasets/the21stcenturymortalityfilesdeathsdataset/",
                      "current/regdeaths2001to2015.xls")

dir.create("data")
curl_download(deaths_file,destfile = "data/c21deaths.xls")


dataset <- readxl::read_excel("data/c21deaths.xls",sheet=3, skip=1)

get_year <- function(sheet, file, skip){
  data <- readxl::read_excel(file,sheet=sheet, skip=skip)
  return(data)
}

sheets <- 3:15

COD_data <- map_df(sheets, get_year, file="data/c21deaths.xls", skip=1)


# 20th Century Mortality Files ------
base <- paste0("http://webarchive.nationalarchives.gov.uk/",
               "20160105160709/http://www.ons.gov.uk/ons/",
               "rel/subnational-health1/the-20th-century-mortality-files/")
url_popC20 <- paste0(base,"20th-century-deaths/populations-1901-2000.xls")
curl_download(url_popC20,destfile = "data/c20pop.xls")

dataset <- readxl::read_excel("data/c21deaths.xls",sheet=3, skip=1)


url_D79_84 <- paste0(base,"20th-century-deaths/1979-1984-icd9a.zip")
url_D85_93 <- paste0(base,"20th-century-deaths/1985-1993-icd9b.zip")
url_D94_00 <- paste0(base,"20th-century-deaths/1994-2000-icd9c.zip")



# Weekly
base <- paste0("https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/",
               "birthsdeathsandmarriages/deaths/datasets/",
               "weeklyprovisionalfiguresondeathsregisteredinenglandandwales/")

dir.create("data/weekly")
get_weekly_year<-function(year, base){
  curl_download(paste0(base, year,"/publishedweek", year,".xls"),
                destfile = paste0("data/weekly/weekly_",year,".xls"))
}

years <- 2010:2015


map(years, get_weekly_year, base)

# latest data for 2016 and 2017
curl_download(paste0(base,"2016/publishedweek522016.xls"),
              destfile = "data/weekly/weekly_2016.xls")


curl_download(paste0(base,"2017/publishedweek522017.xls"),
              destfile = "data/weekly/weekly_2017.xls")


curl_download(paste0(base,"2017/publishedweek522017.xls"),
              destfile = "data/weekly/weekly_2017.xls")

weeks <- 1:52
get_url <- function(week,year,base){
  url <- paste0(base, year,"/publishedweek", week,year, ".xls")
  return(url)
}
data_available <- map_lgl(weeks, function(week, year,base){
    url <- get_url(week, year,base)
    identical(status_code(HEAD(url)), 200L)
  }, year=2018, base=base)

last_week_avail <- tail(which(data_available),1)

url <- get_url(last_week_avail, 2018, base)
curl_download(url,
              destfile = "data/weekly/weekly_2018.xls")




# HMD
user <- Sys.getenv("HFD_user")
pass <- Sys.getenv("HFD_pass")

exp_hmd <- readHMDweb(CNTRY = "GBRTENW", item = "Exposures_1x1", fixup = TRUE,
                      username = user, password = pass)

deaths_hmd  <- readHMDweb(CNTRY = "GBRTENW", item = "Deaths_1x1", fixup = TRUE,
                          username = user, password = pass)

dir.create(file.path("data", "HMD"))
saveRDS(exp_hmd, "data/HMD/exposures_hmd.Rdata")
saveRDS(deaths_hmd, "data/HMD/deaths_hmd.Rdata")
pop_hmd <- readHMDweb(CNTRY = "GBRTENW", item = "Population", fixup = TRUE,
                      username = user, password = pass)
saveRDS(pop_hmd, file="data/HMD/pop_hmd.Rdata")


# Exposures
# Using mid-year population 2015

url <- paste0("https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/",
              "populationandmigration/populationestimates/datasets/",
              "populationestimatesforukenglandandwalesscotlandandnorthernireland/",
              "mid2016detailedtimeseries/ukandregionalpopulationestimates1838to2016.zip")
path <- file.path("data","midyear")


dir.create(path)
filename <- "EW_midyear_2016"
curl_download(url, destfile=file.path(path,paste0(filename,".zip")))
unzip(file.path(path,paste0(filename, ".zip")), exdir=path)

# url <- paste0("https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/",
#               "populationandmigration/populationestimates/datasets/",
#               "populationestimatesforukenglandandwalesscotlandandnorthernireland/",
#                "mid2016/ukmidyearestimates2016.xls")

# old age
url <- paste0("https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/",
             "birthsdeathsandmarriages/ageing/datasets/",
             "midyearpopulationestimatesoftheveryoldincludingcentenariansengland",
             "/current/e2016.xls")
filename <- "england_old"
curl_download(url, destfile=file.path(path,paste0(filename,".xls")))


url <- paste0("https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/",
              "birthsdeathsandmarriages/ageing/datasets/",
              "midyearpopulationestimatesoftheveryoldincludingcentenarianswales",
              "/current/w2016.xls")
filename <- "wales_old"
curl_download(url, destfile=file.path(path,paste0(filename,".xls")))


# forecasts
path <- "data/forecast/"
dir.create(path)

url <- paste0("https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/",
              "populationandmigration/populationprojections/datasets/",
              "z2zippedpopulationprojectionsdatafilesgbandenglandandwales/2016based/",
              "tablez2opendata16ewgb.zip")

curl_download(url,destfile = paste0(path, "forecast.zip"))
unzip(paste0(path, "forecast.zip"), exdir = path)
list.files(path)
# zip(zipfile = file.path(path,"ew_ppp_opendata2016.xlsx"),
#     files = file.path(path,"ew_ppp_opendata2016.xml"))

# unfortunately I couldn't work out an easy way of reading these forecasts directly
# as an xml file.
# xls files are just basically xml files, but I couldn't open these with the
# read_xls functions.
# Unfortunately, I needed to manually open with excel and save out as xlsx before I could
# open from R
# It should be possible to parse these from xml, but it looked like it needed 
# more time to figure out than I had available... Hit me up if you know how.
