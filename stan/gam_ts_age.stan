data{

  int N;
  int n_basis;
  int n_hols;
  int n_ages;

  int deaths[n_ages, N];
  vector[N] expos[n_ages];
  matrix[N, n_basis] season_basis;
  matrix[N, n_hols] hol_X;
  vector[N] time; 

  matrix[n_basis, n_basis] seasonal_covar_unscaled;

}
transformed data{
  vector[N] log_expos[n_ages];
  vector[N] ones;
  vector[n_basis] zeros;
  vector[N] emp_rates[n_ages];
  ones = rep_vector(1, N);
  zeros = rep_vector(0,n_basis);
  log_expos = log(expos);

  for (x in 1:n_ages){
    for (t in 1:N){
      emp_rates[x,t] = 1.0*deaths[x,t]/expos[x,t];
    }
  }

}

parameters {

  vector[n_hols] beta_hols;
  matrix[n_ages, n_basis] seasonal_coefs;
  row_vector[n_ages] trend_coef;
  row_vector[n_ages] intercept;

  real<lower=0> sigma_trend;
  real<lower=0> sigma_intercept;
  real<lower=0> sigma_seasonal;
  real<lower=0> sigma_hols;
}

transformed parameters {
  matrix[n_ages,N] mu;
  matrix[n_ages,N] linear;
  matrix[n_ages,N] spline_seasonal;
  row_vector[N] fixed_hols;
  matrix[n_basis, n_basis] seasonal_covar;

  seasonal_covar = pow(sigma_seasonal,2) * seasonal_covar_unscaled;


  linear =  (ones * intercept + time * trend_coef)';
  
  
  fixed_hols = (hol_X * beta_hols)';

  mu = linear;

  for (x in 1:n_ages){
    spline_seasonal[x] = (season_basis * seasonal_coefs[x]')';
    mu[x] += spline_seasonal[x] + fixed_hols;
  }
   
  
}
model {

  trend_coef ~ normal(0, sigma_trend);
  intercept ~ normal(0, sigma_intercept);
  beta_hols ~ normal(0, sigma_hols);

  sigma_trend ~ normal(0, 10);
  sigma_hols ~ normal(0, 10);
  sigma_intercept ~ normal(0, 10);
  sigma_seasonal ~ normal(0, 10);
  
  

  for (x in 1:n_ages){
    seasonal_coefs[x] ~ multi_normal(zeros, seasonal_covar);
    deaths[x] ~ poisson_log(mu[x] + log_expos[x]');  
  }
  
}
generated quantities{
  matrix[n_ages,N] resid; 
  for (x in 1:n_ages){
    resid[x] = log(emp_rates[x]') - mu[x];
  }
}
 /* int deaths_gen[n_ages, N];
  for (x in 1:n_ages){
    for (i in 1:N){
      deaths_gen[x,i] = poisson_log_rng(mu[x,i] + log_expos[x,i]');  
    }
    
  }
  
}
*/
