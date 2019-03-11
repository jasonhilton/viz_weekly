library(curl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(magrittr)
library(readxl)
library(purrr)
library(lubridate)
library(timeDate)
library(ggfan)
library(rstan)
library(splines)


source("R/data_cleaning_functions.R")

## Engand and Wales

# read data --------------------------------------------------------------------

read_weekly <- function(year,path,prefix,sheet=4, skip=3){
  read_xls(paste0(path, prefix, year, ".xls"),sheet=sheet,skip = skip)
}

years <- 2010:2019

# expect warnings about data formats here
weekly_dfs <- map(years, read_weekly, path="data/weekly/","weekly_", skip=3)
# inexplicably, 2014 is formatted differently
weekly_dfs[[5]] <- read_weekly(2014, path="data/weekly/", prefix = "weekly_", skip=2)

# 2016 and 2017 have two-column indexes. We only need one so:
# copy what we need and remove the first column so the formats are the same as
# period years
weekly_dfs[[8]][1:4,2] <- weekly_dfs[[8]][1:4,1]
colnames(weekly_dfs[[8]])[2] <- colnames(weekly_dfs[[8]])[1]
weekly_dfs[[8]] <- weekly_dfs[[8]][,-1]

weekly_dfs[[7]][1:4,2] <- weekly_dfs[[7]][1:4,1]
colnames(weekly_dfs[[7]])[2] <- colnames(weekly_dfs[[7]])[1]
weekly_dfs[[7]] <-   weekly_dfs[[7]][,-1]

weekly_dfs[[9]][1:4,2] <- weekly_dfs[[9]][1:4,1]
colnames(weekly_dfs[[9]])[2] <- colnames(weekly_dfs[[9]])[1]
weekly_dfs[[9]] <-   weekly_dfs[[9]][,-1]


weekly_dfs[[10]][1:4,2] <- weekly_dfs[[10]][1:4,1]
colnames(weekly_dfs[[10]])[2] <- colnames(weekly_dfs[[10]])[1]
weekly_dfs[[10]] <-   weekly_dfs[[10]][,-1]


# remove row with missing ICD 2001 data in favour of ICD 2010 data
weekly_dfs[[2]] <-   weekly_dfs[[2]][-9,]

# extract the bits we want from each data frame---------------------------------
age_df <- map2_df(weekly_dfs, years, get_age_data, sex="Person")
age_m_df <- map2_df(weekly_dfs, years, get_age_data, sex="Male")
age_f_df <- map2_df(weekly_dfs, years, get_age_data, sex="Female")
# expect warnings here.
region_df <- map2_df(weekly_dfs, years, get_region_df)
cause_df <- map2_df(weekly_dfs, years, get_death_cause)

# problem with one missing week for cause data in 2014. Impute. ----------------
weekly_2014 <- weekly_dfs[[5]]
ICD_2013 <- weekly_2014[9,]
ICD_2010 <- weekly_2014[10,]
est_w1 <- (as.numeric(unlist(ICD_2013)[3]) / as.numeric(unlist(ICD_2010)[3])
           * as.numeric(unlist(ICD_2010)[2]))

other <- cause_df %>% filter(Year==2014, Cause=="Total deaths", Week_number==1) %>%
  select(Deaths) %>%
  unlist() - est_w1
cause_df %<>% mutate(Deaths= ifelse(Cause=="Respiratory deaths" & Year==2014 &
                                      Week_number==1,
                                    est_w1, Deaths)) %>%
  mutate(Deaths=ifelse(Cause=="Other deaths" & Year==2014 & Week_number==1,
                       other, Deaths))

# Generate dates ---------------------------------------------------------------

dates <- map(weekly_dfs, get_date)
last_week <- tail(which(grepl("2019",dates[[length(dates)]])), 1)
dates_complete <- seq.Date(as.Date(dates[[1]][1]),
                           as.Date(dates[[length(dates)]][last_week]),
                           by= "week")

date_df <- cbind(rbind(expand.grid(Week_number_2=1:52, Year=2010:2019),
                       data.frame(Week_number_2=53, Year=2015)) %>%
                   arrange(Year, Week_number_2) %>%
                   filter(!(Year==2019 & Week_number_2 > last_week)),
                 date=dates_complete)

date_df %<>% mutate(Week_end = date,
                    Week_start = date - 7,
                    midweek = Week_end - (Week_end - Week_start)/2,
                    Week_number=week(midweek))

## find public holidays
publicHols <- as.Date(holidayLONDON((range(date_df$Year)[1]):(range(date_df$Year)[2])))

holnames <- c("New_Year", "Christmas", "August","Jubilee", "Mayday",
              "Royal_Wedding", "Spring")

publicHols <- publicHols[publicHols<last(dates_complete)]

# helper function to identify if the a holiday falls within a given week.
is_holiday <- function(date, week_start,week_end,year){
  return(date <= week_end & date > week_start)
}

# variables to be filled in...
date_df %<>% as_tibble() %>%  
  mutate(Holiday=0,
         PH_date=publicHols[1]-1000) # a random past date to allow filtering

# find all the public holidates in the date dataframe
for (ph_date in as.list(publicHols)){
  date_df %<>% mutate(Holiday= Holiday + is_holiday(ph_date, Week_start,Week_end),
                      PH_date=ifelse(is_holiday(ph_date, Week_start,Week_end),
                                     ph_date, PH_date))
}
# convert back to date
date_df %<>% mutate(PH_date= as.Date(PH_date, origin="1970-01-01"))

# find WHICH holiday each one is and give indicator/dummy
date_df %<>% mutate(Month=month(PH_date),
                    New_Year=(month(Week_end)==1 & Holiday>0),
                    Christmas=(Month==12 & Holiday>0),
                    August=(Month==8 & Holiday>0),
                    Jubilee=(Month==6 & Year==2012 & Holiday>0),
                    Mayday=(Month==5 & mday(PH_date) <= 7 & Holiday>0),
                    Royal_Wedding=(Month==4 & Year==2011 & Holiday>0 & 
                                     mday(PH_date)==29),
                    Spring=(Month==5 & mday(PH_date)>=24 & Holiday>0))

Easter <- date_df %>% select(holnames) %>% rowSums()==0 & date_df$Holiday==T
date_df$Easter=Easter
holnames <- c(holnames, "Easter")
date_df %<>% mutate(Week_number=Week_number_2) %>% select(-Week_number_2)

# add dates to death data
cause_df <- left_join(cause_df, date_df %>% select(-PH_date, -Month))
get_cumul_days<-function(midweek, ref_point = as.Date("2010-01-01")){
  return((midweek - ref_point)[[1]])
}
cause_df %<>% mutate(cumul_days = map_dbl(.$midweek, get_cumul_days))
cause_df %<>% filter(Year <=2018 | Week_number <=last_week)
saveRDS(file="data/cause.rds", cause_df)

## ages ------------------------------------------------------------------------
ages_df <- rbind(age_m_df, age_f_df)
ages_df <- left_join(ages_df, date_df %>% select(-PH_date, -Month))
ages_df %<>% mutate(cumul_days = map_dbl(.$midweek, get_cumul_days))
ages_df %<>% filter(Year <2019 | Week_number <=last_week)
saveRDS(file="data/ages.rds",ages_df)

