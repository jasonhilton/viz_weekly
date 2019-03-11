library(curl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(magrittr)
library(readxl)
library(purrr)
library(HMDHFDplus)
library(viridis)
library(ggfan)


###############
## plan
# 1. get yearly exposure data
# 1961-2014 - hmd
# 2015-2016 mid year estimates
# 2017- NPP 2016 forecast?
# 2. divide into weeks.
#   a) naive method - even change


pop_hmd <- readRDS("data/HMD/pop_hmd.Rdata")
exp_hmd <- readRDS("data/HMD/exposures_hmd.Rdata")
deaths_hmd <- readRDS("data/HMD/deaths_hmd.Rdata")
exp_hmd <- exp_hmd %>% mutate(Cohort=Year-Age)
deaths_hmd <- deaths_hmd %>% mutate(Cohort=Year-Age)

# Note Total1 and Total2 are the jan1 and dec31 popsizes for each year
# A consequnce of HMDparse
pop_recent <- pop_hmd %>% filter(Year>=2010) %>% group_by(Age) %>%
  mutate(Total_diff=Total2 - Total1)

# linear interpolation from jan1 to dec31
for(i in 0:52){
  varname <- paste0("Week", i)
  pop_recent <- pop_recent %>% mutate(!!varname := Total1 + (i/52)*Total_diff)
}

# Move to long format
pop_year_end <- pop_recent %>% gather(Week,Count,starts_with("Week")) %>%
  mutate(Week=as.numeric(gsub("Week", "", Week)))

## HMD goes to 2015 jan1

## Use ONS mid-year estimates
path <- "data/midyear/"

total_pop <- read_xlsx(paste0(path,"UK Population Estimates 1838-2016.xlsx"),
                       sheet="Table 9",
                       range="A5:BE98")
total_pop <- total_pop[-1,]


male_pop <- read_xlsx(paste0(path,"UK Population Estimates 1838-2016.xlsx"),
                      sheet="Table 9",
                      range="A100:BE192")

female_pop <- read_xlsx(paste0(path,"UK Population Estimates 1838-2016.xlsx"),
                        sheet="Table 9",
                        range="A194:BE286")

## old age ---------------------------------------------------------------------
# Read from seperate sheets for Wales and England, with different ranges for
# total, males females.

# Total pop --- old age
total_pop_eng_old <- read_xls(file.path(path, "england_old.xls"),sheet="England",
                              range = "B9:V24")

total_pop_eng_old <- total_pop_eng_old[,-(2:5)]
colnames(total_pop_eng_old) <- c("Year", 90:105)

total_pop_wales_old <- read_xls(file.path(path, "wales_old.xls"),sheet="Wales",
                              range = "B9:V24")

total_pop_wales_old <- total_pop_wales_old[,-c(2:5)]
colnames(total_pop_wales_old) <- c("Year", 90:105)

# Add together england and wales populations -old -- total pop
total_pop_ew_old <-(total_pop_eng_old + total_pop_wales_old) %>% mutate(Year=Year/2)

# Males --- old age
males_pop_eng_old <- read_xls(file.path(path, "england_old.xls"),sheet="England",
                              range = "B30:V44")

males_pop_eng_old <- males_pop_eng_old[,-(2:5)]
colnames(males_pop_eng_old) <- c("Year", 90:105)

males_pop_wales_old <- read_xls(file.path(path, "wales_old.xls"),sheet="Wales",
                                range = "B30:V44")

males_pop_wales_old <- males_pop_wales_old[,-c(2:5)]
colnames(males_pop_wales_old) <- c("Year", 90:105)

# Add together england and wales populations - old - males
males_pop_ew_old <-(males_pop_eng_old + males_pop_wales_old) %>% mutate(Year=Year/2)

# females --- old age
females_pop_eng_old <- read_xls(file.path(path, "england_old.xls"),sheet="England",
                              range = "B50:V64")

females_pop_eng_old <- females_pop_eng_old[,-(2:5)]
colnames(females_pop_eng_old) <- c("Year", 90:105)

females_pop_wales_old <- read_xls(file.path(path, "wales_old.xls"),sheet="Wales",
                                range = "B50:V64")

females_pop_wales_old <- females_pop_wales_old[,-c(2:5)]
colnames(females_pop_wales_old) <- c("Year", 90:105)

# Add together england and wales populations - old - females
females_pop_ew_old <- (females_pop_eng_old + females_pop_wales_old) %>% mutate(Year=Year/2)

# reconstitute into single old age pop
old_pops <- list(total_pop_ew_old, males_pop_ew_old, females_pop_ew_old)

old_pop_df <- map2_df(old_pops, c("Total","Male", "Female"),
                      function(df,sex) as_tibble(df) %>%
                        gather(Age,Midyear_pop, -Year) %>%
                        mutate(Age=as.numeric(Age), Sex=sex)
                      )

# 2017-2019 data ---------------------------------------------------------------
# from ons population projections
path <- "data/forecast/"

pop_fore <- read_xlsx(paste0(path, "ew_ppp_opendata2016.xlsx"),
                      sheet="Population")


pop_fore <- pop_fore %>% mutate(Age=ifelse(Age=="105 - 109",105,Age),
                                Age=ifelse(Age=="110 and over",110,Age),
                                Age = as.numeric(Age))


pop_fore_old <- filter(pop_fore, Age >= 105) %>%
  gather(Year, Midyear_pop, -Sex,-Age) %>%
  mutate(Sex=ifelse(Sex==1, "Male", "Female"))

# crude interpolation between 105-110
interpolate_age <- function(df){
  x110 <- df$Midyear_pop[2]
  x105 <- df$Midyear_pop[1]
  xx <- c((x105 - x110*5) * exp(5:1) /sum(exp(5:1)) + rep(x110,5),x110)
  out_df <- tibble(Age=105:110, Midyear_pop=xx)
  return(out_df)
}

pop_fore_old %<>% ungroup() %>% nest(c(Age, Midyear_pop)) %>%
  mutate(out=map(data, interpolate_age)) %>%
  select(-data) %>% unnest()

extra_old <- expand.grid(Sex=unique(old_pop_df$Sex),
                         Age=110,
                         Midyear_pop=0,
                         Year=unique(old_pop_df$Year))

old_pop_df %<>% rbind(extra_old) %>% arrange(Sex, Year,Age)

v_old_pop_df <- old_pop_df %>% filter(Age > 104) %>% nest(c(Age,Midyear_pop)) %>%
  mutate(out=map(data, interpolate_age)) %>%
  select(-data) %>% unnest()

old_pop_df %<>% filter(Age<105) %>% rbind(v_old_pop_df) %>% arrange(Sex, Year,Age)


# start sticking the young and old pieces back together
pop_fore %<>% gather(Year, Midyear_pop, -Sex,-Age) %>%
  mutate(Sex=ifelse(Sex==1, "Male", "Female"))

pop_fore <- rbind(pop_fore %>% filter(Age<105),
                  pop_fore_old) %>% mutate(Year=as.numeric(Year))

pop_fore_total <- pop_fore %>% group_by(Age,Year) %>%
  summarise(Midyear_pop=sum(Midyear_pop)) %>% mutate(Sex="Total")

pop_fore_df <- rbind(pop_fore, pop_fore_total %>% ungroup())


names(male_pop) <- names(female_pop) <-names(total_pop)
tidy_df <- function(df){
  df <- df %>% mutate_at(vars(starts_with("Mid")), as.numeric)
  df %>% gather(key=Year,value=Midyear_pop, starts_with("Mid"))
}

pop_df <- do.call(rbind,list(Total=total_pop %>% mutate(Sex="Total"),
                             Male=male_pop %>% mutate(Sex="Male"),
                             Female=female_pop %>% mutate(Sex="Female")))

pop_df <- tidy_df(pop_df) # Creates NAs but only 1960s...

pop_df <- pop_df %>%
  mutate(Year=as.numeric(gsub("Mid-", "", Year)))

pop_df <- rbind(pop_df %>%  filter(Age!="All Ages" & Age!="90+") %>%
                  mutate(Age=as.numeric(gsub("\\+", "", Age))),
                old_pop_df)

pop_df %<>% rbind(pop_fore_df %>% filter(Year>2016)) %>% arrange(Sex,Year,Age)

# lose later years
pop_df %<>% filter(Year<= 2019)
pop_df <- pop_df %>% group_by(Sex,Age) %>% arrange(Year) %>%
  mutate(Midyear_pop_lag = lag(Midyear_pop),
         Midyear_pop_lead = lead(Midyear_pop))

saveRDS(pop_df, "data/mid_year_pop.rds")

# Interpolate between year ends to get weekly data.
# 2015 has an extra week...

for(i in 0:26){
  varname <- paste0("Week", i)
  varname2 <- paste0("Week", i+26)

  # week 26 get assigned twice, but that's ok.
  pop_df <- pop_df %>% group_by(Sex,Age) %>%
    mutate(!!varname := Midyear_pop_lag + (0.5 + i/52) *
              (Midyear_pop-Midyear_pop_lag),
            !!varname2 := Midyear_pop + (i/52) *
              (Midyear_pop_lead - Midyear_pop))
}

for (i in 0:26){
    varname <- paste0("Week", i)
    varname2 <- paste0("Week", i+27)
    pop_df_2015 <- pop_df %>% filter(Year==2015) %>% group_by(Sex,Age) %>%
      mutate(!!varname := Midyear_pop_lag + (26/53 + i/53) *
             (Midyear_pop-Midyear_pop_lag),
           !!varname2 := Midyear_pop + (i/52) *
             (Midyear_pop_lead - Midyear_pop))
    varname2 <- paste0("Week", i+26)
    pop_df_2014 <- pop_df %>% filter(Year==2014) %>% group_by(Sex,Age) %>%
      mutate(!!varname2 := Midyear_pop + (i/53) *
              (Midyear_pop_lead - Midyear_pop))

}

pop_df <- pop_df %>% ungroup() %>%  gather(key=Week,value=Week_pop,starts_with("Week")) %>%
  mutate(Week=as.numeric(gsub("Week","", Week)))

pop_2014_2015 <- rbind(pop_df_2014,pop_df_2015) %>%
  gather(key=Week,value=Week_pop,starts_with("Week")) %>%
  mutate(Week=as.numeric(gsub("Week","", Week))) %>% filter(!(Year==2014 & Week==53))

pop_df <- rbind(pop_df %>% filter(Year!=2014, Year!=2015),
                pop_2014_2015 %>% ungroup())

exp_df <- pop_df %>% group_by(Age,Year,Sex) %>% arrange(Week) %>%
  mutate(Week_exp = (Week_pop + lag(Week_pop))/(52*2)) %>%
  filter(Week!=0)

exp_df %<>% mutate(Week_number=Week)

saveRDS(exp_df, "data/exp.rds")