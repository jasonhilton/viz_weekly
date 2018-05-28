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
library(broom)

source("R/data_cleaning_functions.R")

cause_df <- readRDS("data/cause.rds")
exp_df <- readRDS("data/exp.rds")


# start with simple all-cause data

total_deaths_df <- cause_df %>% filter(Cause=="Total deaths") %>%
  rename(Week=Week_number)

latest_week <- cause_df %>% filter(Year==2018) %>%
  select(Week_number) %>% unlist() %>% max()

exp_total_df <- exp_df %>% ungroup() %>% filter(Sex=="Total") %>%
  group_by(Year,Week) %>%
  summarise(Week_exp=sum(Week_exp)) %>%
  filter(Year>2009, Year <2018 | Week <= latest_week)

data_df <- left_join(total_deaths_df, exp_total_df)

# model matrix for public holiday fixed effects --------------------------------
# public holidays cause death registrations to move from one week to the next
# so the effect should take the form 1,-1 for consecutive weeks
hol_mat <- data_df %>%
  select(New_Year, Easter, Royal_Wedding, Mayday, Spring, Jubilee, August,
         Christmas) %>% as.matrix() %>% apply(1,as.numeric) %>% t()

hol_mat_minus <- rbind(c(-1,rep(0,7)), -hol_mat[-(dim(hol_mat)[1]),])

hol <- hol_mat + hol_mat_minus
# note at easter we have a 1,0,-1 pattern because of two consecutive holidays..
# [1,-1,0] + [0,1,-1] = [1,0,-1]
holiday_names <- c("New_Year", "Easter", "Royal_Wedding", "Mayday",
                   "Spring", "Jubilee", "August", "Christmas")
colnames(hol) <- holiday_names


data_df <- data_df %>% select(-New_Year, -Easter, -Royal_Wedding, -Mayday,
                  -Spring, -Jubilee, -August, -Christmas) %>%
  cbind(hol)

## seasonal periodic spline ----------------------------------------------------
n_basis <- 9

XX <- get_periodic_spline(yday(data_df$midweek), n_basis)

N <- dim(data_df)[1]
# Sum to zero constraint (over whole period 2010-2017)
SS <- solve(get_difference_matrix(n_basis))
Z <- diag(n_basis)
Z[1,] <- matrix(1,1,N) %*% XX %*% SS
XX_star <- (XX %*% SS %*% solve(Z))[,2:n_basis]
colnames(XX_star) <- paste0("S",1:(n_basis-1))

# conditional MVN unscaled prior covariance
Sig <- Z %*% t(Z)
Tau <- diag(n_basis - 1) - Sig[2:n_basis,1] %*% solve(Sig[1,1]) %*% Sig[1,2:n_basis]


# normalise time index
#data_df %<>% mutate(tt=(cumul_days- mean(cumul_days))/sd(cumul_days))

# convert to annual coefficient with intercept
data_df %<>% mutate(tt=(cumul_days- mean(cumul_days))/365)

spline_names <- paste0("S", 1:(n_basis-1))
colnames(XX_star) <- spline_names
data_df <- cbind(data_df, XX_star)

# maximum likelihood --------------------------------------------------------
mod_formula <- "Deaths ~ tt + "
mod_formula <- paste0(mod_formula,
                      paste(c(spline_names,holiday_names), collapse=" + "))
mod_test <- glm(mod_formula,
                family = poisson,
                offset = log(Week_exp),
                data=data_df)
# plot(data_df$midweek, exp(predict(mod_test)), type="l")
# points(data_df$midweek, data_df$Deaths, col="red")

# MCMC -------------------------------------------------------------------
stan_data <- list(deaths = data_df$Deaths,
                  N=N,
                  n_basis=(n_basis-1),
                  n_hols = dim(hol)[2],
                  hol_X  =hol,
                  season_basis= XX_star,
                  expos = data_df$Week_exp,
                  time = data_df$tt,
                  seasonal_covar_unscaled=Tau)

simple_model <- stan_model("stan/gam_ts_pois.stan")
death_fit <- sampling(simple_model, data=stan_data,
                      iter=2000, cores=3,chains=3)

# stan_diag(death_fit)
# stan_rhat(death_fit)
# stan_diag(death_fit, "stepsize")
# stan_trace(death_fit, "lp__")

mu <- as.matrix(death_fit, "mu")

mu_df <- mu %>% t() %>% as_tibble() %>% mutate(Date=data_df$midweek) %>%
  gather(Sim, CMR_mean, -Date)

data_df %<>% mutate(CMR=Deaths/Week_exp)
# ggplot(mu_df, aes(x=Date,y=CMR_mean)) + stat_sample(aes(group=Sim),n_samples=1000) +
#   geom_point(data=data_df, aes(x=midweek, y=log(CMR)),colour="red") +
#   theme_bw()

linear <- as.matrix(death_fit, "linear")
linear_df <- linear %>% t() %>% as_tibble() %>%
  mutate(Date=data_df$midweek,
         Year=data_df$Year,
         Week=data_df$Week,
         Day_of_year=yday(data_df$midweek)) %>%
  gather(Sim, Trend, -Date, -Year, -Week,-Day_of_year)
# ggplot(linear_df, aes(x=Day_of_year,y=Trend)) +
#   stat_sample(aes(group=interaction(Sim,Year)),n_samples=1000) +
#   theme_bw()# + coord_polar()

hols <- as.matrix(death_fit, "fixed_hols")


hols_df <- hols %>% t() %>% as_tibble() %>%
  mutate(Date=data_df$midweek,
         Year=data_df$Year,
         Week=data_df$Week) %>%
  gather(Sim, Holidays, -Date, -Year, -Week)

dir.create("results")
saveRDS(hols_df, file.path("results", "hols.rds"))

# ggplot(hols_df, aes(x=Week,y=Holidays)) +
#   stat_sample(aes(group=interaction(Sim,Year)),n_samples=1000) +
#   theme_minimal() + coord_polar()
#
# ggplot(hols_df, aes(x=Week,y=Holidays,group=Year, fill=Year)) +
#   geom_bar(stat = "summary",position="identity") + coord_polar() +
#   theme_minimal() + geom_hline(yintercept=0)

get_linerange <- function(x){
  out <- quantile(x, probs=c(0.025,0.5,0.975))

  names(out) <- c("ymin","y", "ymax")
  return(out)
}
# ggplot(hols_df, aes(x=Week,y=Holidays,group=Year, fill=Year)) +
#   geom_bar(stat = "summary",position="identity") + coord_polar() +
#   geom_linerange(stat="summary", fun.data=get_linerange) +
#   theme_minimal() + geom_hline(yintercept=0) + scale_fill_viridis()


seasonal <- as.matrix(death_fit, "spline_seasonal")

seasonal_df <- seasonal %>% t() %>% as_tibble() %>%
  mutate(Day=yday(data_df$midweek),
         Date=data_df$midweek,
         Year=data_df$Year,
         Week=data_df$Week) %>%
  gather(Sim, Seasonal, -Day, -Year, -Week,-Date)
# ggplot(seasonal_df, aes(x=Day,y=exp(Seasonal))) +
#   stat_sample(aes(group=interaction(Sim,Year)),n_samples=1000) +
#   theme_bw() + coord_polar()
#
# ggplot(seasonal_df, aes(x=Day,y=Seasonal)) +
#   geom_interval(colour="darkgreen") +
#   theme_minimal() + coord_polar() + ylim(-0.2,0.2) +
#   geom_hline(yintercept=0, colour="red")
saveRDS(seasonal_df, file="results/seasonal.rds")

mu_df %<>% left_join(data_df %>% mutate(Date=midweek))

resid_df <- mu_df %>% mutate(Residual = log(CMR) -CMR_mean) %>%
  select(Date, Sim, Residual,Week, Year)
resid_df %<>% mutate(Day=yday(Date))

# ggplot(resid_df, aes(x=Date,y=Residual)) +
#   stat_sample(aes(group=Sim), n_samples=1000)

saveRDS(resid_df, "results/resid.rds")

outd3 <- resid_df %>% group_by(Date) %>% summarise(Residual=mean(Residual)) %>%
  mutate(yday=yday(Date))

# write.table(outd3, file.path("html","mod2.csv"), sep=",",
#             row.names=F)

write.table(outd3, file.path("paper","mod2.csv"), sep=",",
            row.names=F)

## age_specific ----------------------------------------------------------------


ages_df <- readRDS("data/ages.rds")
exp_df <- readRDS("data/exp.rds")

last_week <- ages_df %>% filter(Year==2018) %>%
  select(Week_number) %>% unlist() %>% tail(1)

# males first
deaths_ages <- ages_df  %>%
  select(Age_group, Deaths, midweek,Sex) %>%
  spread(Age_group, Deaths)

nms <- names(deaths_ages)
nms_to_select <- nms[c(length(nms),3:(length(nms)-1))]
deaths_m <- deaths_ages %>% filter(Sex=="Male") %>%
  select(nms_to_select) %>% as.matrix() %>% t()

deaths_f <- deaths_ages %>% filter(Sex=="Female") %>%
  select(nms_to_select) %>% as.matrix() %>% t()

expos_ages <- exp_df %>% arrange(Year,Week) %>%
  filter(Year>2009, Year<2018 | Week <= last_week) %>%
  mutate(Age_group=cut(Age ,c(0,1,15,45,65,75,85,111), right=F)) %>%
  group_by(Week, Year, Sex, Age_group) %>%
  summarise(Week_exp=sum(Week_exp)) %>%
  spread(Age_group, Week_exp)

expos_m <- expos_ages %>% ungroup() %>% filter(Sex=="Male") %>% 
  arrange(Year,Week)  %>%
  select(-Week, -Year, -Sex) %>% as.matrix() %>% t()

expos_f <- expos_ages %>% ungroup() %>% filter(Sex=="Female") %>%
  arrange(Year,Week)  %>%
  select(-Week, -Year, -Sex) %>% as.matrix() %>% t()



stan_data <- list(deaths = deaths_m,
                  N=N,
                  n_basis=n_basis-1,
                  n_hols = dim(hol)[2],
                  n_ages =dim(expos_m)[1],
                  hol_X  =hol,
                  season_basis= XX_star,
                  expos = expos_m,
                  time = data_df$tt,
                  seasonal_covar_unscaled=Tau)


age_model <- stan_model("stan/gam_ts_age.stan")
death_fit <- sampling(age_model, data=stan_data,
                      iter=2000, cores=3,chains=3)

mu <- as.matrix(death_fit, "mu")

#data_df %>% filter(Sex=="Male")
mu_df <- mu %>% t() %>% as_tibble() %>%
  mutate(Date = rep(data_df$midweek %>% unique() %>% sort(),
                    rep(stan_data$n_ages, stan_data$N)),
         Age= rep(ages_df$Age_group %>% unique(), stan_data$N)) %>%
  gather(Sim, Rate, -Age, -Date)



expos_ages <- expos_ages %>% filter(Sex!="Total") %>% ungroup() %>%
  gather(Age_group, Week_exp, -Week, -Year, -Sex) %>%
  arrange(Year,Week, Sex, Age_group)

key_code <- as.list(setNames(unique(ages_df$Age_group),
                             unique(expos_ages$Age_group)))

expos_ages %<>%  mutate(Age_group=recode(Age_group,
                        !!!key_code))

data_df <- left_join(ages_df %>% rename(Week=Week_number), expos_ages)

data_df %<>% mutate(Rate = Deaths/Week_exp)

# mu_df %>% filter(Age=="85+") %>% ggplot(aes(x=Date, y=Rate, group=Sim)) +
#   stat_sample(n_samples=1000)

#plot(death_fit,pars= "trend_coef")  + geom_vline(xintercept=0)

# mu_df %>% ggplot(aes(x=Date, y=Rate, group=Sim)) +
#   stat_sample(n_samples=1000) +
#   facet_wrap(~Age, scales="free") +
#   geom_point(data=data_df %>% rename(Age=Age_group) %>% filter(Sex=="Male"),
#              aes(x=date, y=log(Rate), group="Empirical"), colour="red")

# mu_df %>% ggplot(aes(x=Date, y=Rate, group=Sim)) +
#   stat_sample(n_samples=1000) +
#   facet_wrap(~Age, scales="free") +
#   geom_point(data=data_df %>% rename(Age=Age_group) %>% filter(Sex=="Male"),
#              aes(x=date, y=log(Rate), group="Empirical"), colour="red")


mu_df %<>% rename(Mean_rate=Rate, Age_group=Age) %>%
  left_join(data_df %>% mutate(Date=midweek) %>% filter(Sex=="Male"))

mu_mean_df <- mu_df %>% mutate(Resid=log(Rate) - Mean_rate) %>% 
  group_by(Age_group, Date) %>% summarise(Residual=mean(Resid)) %>% 
  mutate(yday= yday(Date))

write.table(mu_mean_df, file.path("paper","mod3.csv"), sep=",",
            row.names=F)

saveRDS(mu_mean_df %>% mutate(Week=week(Date)),"results/resid_age.rds")

resid <- as.matrix(death_fit, "resid")
resid %<>% t() %>% as_tibble() %>% 
  mutate(Age_group=rep(unlist(key_code),stan_data$N),
         Date=rep(ages_df$midweek %>% unique(), 
                  rep(7, stan_data$N)))

resid %>% gather(Sim, Residual, - Age_group, -Date) %>% 
  ggplot(aes(x=Date, y= Residual)) + geom_interval() +facet_wrap(~Age_group)



  ## Comparison with long run rates of decline -----------------------------------
# deaths <- readRDS("data/HMD/deaths_hmd.Rdata")
# expos <- readRDS("data/HMD/exposures_hmd.Rdata")
# 
# deaths %<>% select(-OpenInterval) %>% gather(Sex, Deaths, -Year,-Age)
# expos %<>% select(-OpenInterval) %>% gather(Sex, Exposure, -Year,-Age)
# hmd_df <- left_join(deaths, expos)
# hmd_df %<>% mutate(Age_group=cut(Age,c(0,1,15,45,65,75,85,120), right=F))
# 
# 
# ## average mean age
# age_mean <- hmd_df %>% group_by(Age_group, Sex, Year) %>%
#   summarise(Mean_age=weighted.mean(Age,Exposure))
# 
# age_mean %>% filter(Year > 1950) %>%
#   ggplot(aes(x=Year, y=Mean_age, group=Sex, colour=Sex)) +
#   geom_line() + facet_wrap(~Age_group, scales="free")
# 
# hmd_grouped <- hmd_df %>%
#   group_by(Age_group, Sex, Year) %>%
#   summarise(Exposure=sum(Exposure), Deaths=sum(Deaths)) %>%
#   mutate(Rate=Deaths/Exposure)
# 
# ggplot(hmd_grouped %>% filter(Year>1950 , Year < 2010),
#        aes(x=Year, y=log(Rate),group=Age_group, colour=Age_group))  +
#   geom_line() + facet_wrap(~Sex)
# 
# fit_lm <- function(x) lm(log(Rate) ~ Year, data=x)
# hmd_modeled <- hmd_grouped %>% filter(Year>1960, Year < 2010) %>%
#   nest(-Age_group) %>%
#   mutate(model=map(data, fit_lm)) %>% mutate(coefs=map(model, tidy))
# 
# trends <- hmd_modeled %>% select(-data, -model) %>%
#   unnest() %>% filter(term=="Year")
# 
# ggplot(trends, aes(x=Age_group, y=estimate,colour=Sex)) + geom_point(stat="identity")
# 
# conversion <- diff(stan_data$time) * 52
# 
# trend_coef <- as.matrix(death_fit, "trend_coef")
# 
# trend_coef %<>% t() %>% as_tibble() %>%
#   mutate(Age_group=unique(trends$Age_group)) %>%
#   gather(Sim, estimate, -Age_group)
# 
# #data_df$cumul_days %>% `/`(365) %>% unique() %>% mean()
# t_hat <- data_df$tt %>% range() %>% max()
# 
# intercept <- as.matrix(death_fit, "intercept") %>% t() %>% as_tibble() %>%
#   mutate(Age_group=unique(trends$Age_group)) %>%
#   gather(Sim, intercept, -Age_group)
# 
# 
# trend_coef %<>%
#   group_by(Age_group) %>%
#   summarise(estimate=mean(estimate),
#             est_95= quantile(estimate,0.95),
#             est_5=quantile(estimate,0.05))
# 
# new_intercept <- left_join(intercept,trend_coef) %>%
#   mutate(gamma=intercept - estimate*t_hat)
# 
# 
# ggplot(trends, aes(x=Age_group, y=estimate,colour=Sex)) + geom_point(stat="identity")
# 
# trends %>% filter(Sex=="Male") %>% ggplot(aes(x=Age_group,y=estimate)) +
#   geom_hline(yintercept=0) + geom_point() +
#   geom_pointrange(data=trend_coef,
#                   aes(y=est_median,ymax=est_95,ymin=est_5), colour="red") +
#   theme_minimal()
# 
# trend_df <- trend_coef %>% mutate(Period="2010-2018") %>%
#   select(-est_95,-est_5) %>%
#   rbind(trends %>% filter(Sex=="Male") %>%
#           select(Age_group,estimate) %>% mutate(Period="1960-2010"))
# 
# ggplot(trend_df ,aes(x=Age_group,y=estimate,colour=Period)) + geom_point() +
#   theme_minimal() + geom_hline(yintercept=0) +
#   ggtitle("Gradient in log rates by age over different periods - Male")
# 
# saveRDS(trend_df, "results/trend_df.rds")
# 
# 
# 
# key_code <- as.list(setNames(unique(data_df$Age_group),
#                              unique(trend_df$Age_group)))
# 
# trend_df %<>%  mutate(Age_group=recode(Age_group,
#                                          !!!key_code))
# 
# 
# linear_trend <- left_join(data_df %>% filter(Sex=="Male"),
#                           trend_df %>% filter(Period=="1960-2010") %>%
#             select(-Period) %>%
#               mutate(Age_group=as.character(Age_group))) %>%
#   as_tibble() %>% mutate(linear=estimate*(tt-min(tt))) %>%
#   select(Age_group, Week, midweek, linear)
# 
# key_code <- as.list(setNames(unique(data_df$Age_group),
#                              unique(new_intercept$Age_group)))
# 
# 
# new_intercept %<>% mutate(Age_group=as.character(recode(Age_group,
#                                                         !!!key_code)))
# new_intercept %<>% group_by(Age_group) %>% summarise(gamma=mean(gamma))
# 
# linear_trend %<>% left_join(new_intercept) %>% mutate(trend=linear+gamma)
# 
