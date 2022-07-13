//
// This Stan program defines a simple model, with a
// vector of values 'y' modeled as normally distributed
// with mean 'mu' and standard deviation 'sigma'.
//
// Learn more about model development with Stan at:
//
//    http://mc-stan.org/users/interfaces/rstan.html
//    https://github.com/stan-dev/rstan/wiki/RStan-Getting-Started
//

data {
  int<lower=0> N;
  int<lower=1> Ksites;
  int<lower=0,upper=1> recurrence[N];
  vector<lower=0>[N] dose_mg_kg;
  int<lower=1,upper=Ksites> studysite[N];
  int K;
  vector<lower=0>[K] pred_x;
}

// The parameters accepted by the model. Our model
// accepts two parameters 'mu' and 'sigma'.
parameters {
  real E0;
  real Emax;
  real<lower=0> ED50;
  real<lower=0> k;
  real<lower=0> sigma;
  vector[Ksites] E0_site;
  
}

transformed parameters {
  vector[N] pred;
  for(i in 1:N){
    pred[i] = E0+E0_site[studysite[i]] + (pow(dose_mg_kg[i],k)*Emax)/(pow(dose_mg_kg[i],k) + pow(ED50,k));
  }
}
model {
  E0_site ~ normal(0, sigma);
  k ~ exponential(1);
  E0 ~ normal(0,1);
  Emax ~ normal(-3,2);
  ED50 ~ normal(5,2);
  sigma ~ normal(0.25,0.5);
  recurrence ~ bernoulli_logit(pred);
}

// this outputs predicted probabilities of recurrence for the set of doses in pred_x
generated quantities {
  vector[K] pred_y;
  for(i in 1:K){
    pred_y[i] = inv_logit(E0 + (pow(pred_x[i],k)*Emax)/(pow(pred_x[i],k) + pow(ED50,k)));
  }
}

