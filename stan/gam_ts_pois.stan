data{

  int N;
  int n_basis;
  int n_hols;

  int deaths[N];
  vector[N] expos;
  matrix[N, n_basis] season_basis;
  matrix[N,n_hols] hol_X;
  vector[N] time;

  matrix[n_basis, n_basis] seasonal_covar_unscaled;


}
transformed data{
  vector[N] log_expos;
  vector[n_basis] zeros;
  log_expos = log(expos);
  zeros = rep_vector(0,n_basis);
}

parameters {

  vector[n_hols] beta_hols;
  vector[n_basis] seasonal_coefs;
  real trend;

  real<lower=0> sigma_seasonal;
  real<lower=0> sigma_hols;
  real intercept;
}

transformed parameters {
  vector[N] mu;
  vector[N] linear;
  vector[N] spline_seasonal;
  vector[N] fixed_hols;
  matrix[n_basis, n_basis] seasonal_covar;

  seasonal_covar = pow(sigma_seasonal,2) * seasonal_covar_unscaled;

  linear = intercept + trend * time;
  spline_seasonal = season_basis * seasonal_coefs;
  fixed_hols = hol_X * beta_hols;

  mu = linear + spline_seasonal + fixed_hols;
  
}
model {


  trend ~ normal(0, 1);
  intercept ~ normal(0, 1);
  beta_hols ~ normal(0, sigma_hols);

  
  sigma_hols ~ normal(0, 1);
  sigma_seasonal ~ normal(0, 1);
  seasonal_coefs ~ multi_normal(zeros, seasonal_covar);
  deaths ~ poisson_log(mu + log_expos);
}
