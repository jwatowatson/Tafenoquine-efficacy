data {
  int<lower=0> N;
  int<lower=1> Ksites;
  int<lower=0,upper=1> recurrence[N];
  vector<lower=0>[N] dose_mg_kg;
  int<lower=1,upper=Ksites> studysite[N];
  int<lower=0> K_cov;   // number of predictors
  matrix[N, K_cov] x;   // predictor matrix
  int K;
  vector<lower=0>[K] pred_x;
}

parameters {
  // hyperparameters
  real<lower=0> sigmasq_u;        // variance of random effects
  
  real E0;
  real Emax;
  real<lower=0> ED50;
  real<lower=0> k;
  vector[K_cov] beta;       // coefficients for predictors
  
  // Random effects
  vector[Ksites] theta;            // site random effects vector
  
}

transformed parameters {
  vector[N] pred;
  for(i in 1:N){
    pred[i] = E0+ x[i] * beta + theta[studysite[i]] + ( pow(dose_mg_kg[i],k)*Emax )/(pow(dose_mg_kg[i],k) + pow(ED50,k));
  }
}
model {
  
  sigmasq_u ~ normal(0.5, 0.5) T[0, ];
  
  // site random effects
  theta ~ normal(0, sigmasq_u);
  
  // Population parameters
  k ~ normal(1,2) T[0,];
  E0 ~ normal(0,2);
  Emax ~ normal(-5,5);
  ED50 ~ normal(5,5);
  beta ~ normal(0,1);
  
  //***** Likelihood *****
  recurrence ~ bernoulli_logit(pred);
}

// this outputs predicted probabilities of recurrence for the set of doses in pred_x
generated quantities {
  vector[K] pred_y;
  for(i in 1:K){
    pred_y[i] = E0 + (pow(pred_x[i],k)*Emax)/(pow(pred_x[i],k) + pow(ED50,k));
  }
}

