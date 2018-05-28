# Weekly data function

get_death_cause <- function(weekly_df,year){
  print(year)
  total_row <- grep("Total deaths, all ages", weekly_df$`Week number`)[1]
  ICD_row <- grep("ICD", weekly_df$`Week number`)[1]
  total_df <-weekly_df[c(total_row,ICD_row),]
  total_df[,1] <- c("Total deaths", "Respiratory deaths")
  total_df <- rename(total_df, Cause=`Week number`)
  max_week <- colnames(weekly_df)[dim(weekly_df)[2]]
  total_df <- mutate_at(total_df,vars(num_range(prefix="",1:max_week)),as.numeric)
  # take the difference between the causes of death for each week.
  other_deaths <- c("Other deaths",
                    -apply(select(total_df,num_range(prefix="",1:max_week)), 2, diff))
  total_df <- rbind(total_df, other_deaths)
  total_df <- gather(total_df,key="Week_number", value="Deaths",-Cause)
  total_df <- mutate(total_df,Year=year, Week_number=as.numeric(Week_number),
                     Deaths=as.numeric(Deaths))
  return(total_df)
}

get_date<-function(weekly_df){
  date_row <- weekly_df[grep("Week ended", weekly_df$`Week number`),2:dim(weekly_df)[2]]
  date_row <- as.POSIXct(as.numeric(date_row) * (60*60*24),
                         origin="1899-12-30",
                         tz="GMT")
  return(date_row)
}


get_region_df <-function(weekly_df,year){
  # Assumes Wales is the last row in regions.
  print(year)
  region_rows <- ((grep("Deaths by Region|Deaths by region", weekly_df$`Week number`) + 1):
                    grep("^Wales", weekly_df$`Week number`))
  region_df <- weekly_df[region_rows,] %>% rename(Region=`Week number`) %>%
    gather(key=Week,value=Deaths,-Region) %>% mutate(Week=as.numeric(Week),
                                                     Deaths=as.numeric(Deaths),
                                                     Year=year)
  return(region_df)
}


get_age_data <- function(weekly_df, sex, year){
  print(year)
  weekly_df <- weekly_df[1:grep("^Wales", weekly_df$`Week number`),]
  age_rows <- grep(sex, weekly_df$`Week number`) + 2:8

  age_df <- weekly_df[age_rows,]
  # some years nominally have 53 weeks.
  max_week <- colnames(weekly_df)[dim(weekly_df)[2]]
  age_df <- mutate_at(age_df, vars(num_range(prefix="", 1:max_week)), as.numeric) %>%
    rename(Age_group=`Week number`)
  age_df <- age_df %>% gather(key=Week_number, value=Deaths, -Age_group) %>%
    mutate(Week_number =as.numeric(Week_number),
           Year=year,
           Sex=sex)
  return(age_df)
}


## make periodic spline --------------------------------------------------------
# knots must start and end at 31 dec, and have equal spacing
# so that knots outside the data wrap around
# the first basis function is also the third-last basis function
# the third basis function is also the last basis function...

get_periodic_spline <- function(day_of_year_vec, n_basis){
  xx <- day_of_year_vec
  kk <- seq(0,366,length.out=n_basis+1)
  stepsize <- diff(kk)[1]
  kk <- c(c(-3,-2,-1) * stepsize,kk,max(kk) + c(1,2,3) * stepsize)
  XX <- splineDesign(kk,xx)
  # copy end knots into early knot basis functions
  XX[,1] <- XX[,1] + XX[,n_basis + 1]
  XX[,2] <- XX[,2] + XX[,n_basis + 2]
  XX[,3] <- XX[,3] + XX[,n_basis + 3]
  XX <- XX[,1:n_basis]
  return(XX)
}


get_difference_matrix <- function(n){
  D <- matrix(0, n, n)
  D[2:n, 1:(n - 1)] <- - diag(n - 1)
  D <- D + diag(n)
  return(D)
}


# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
# Taken from:
# http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                     ncol = cols, nrow = ceiling(numPlots/cols))
  }
  
  if (numPlots==1) {
    print(plots[[1]])
    
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}
