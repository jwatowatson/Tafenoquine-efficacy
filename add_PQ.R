
# WWARN collated baseline and outcome data
outcome_dat = read_dta('an1_tq_efficacy.dta')
outcome_dat$study =
  plyr::mapvalues(outcome_dat$sid,
                  from = c('BSAJK',
                           'KTMTV',
                           'PRSXC'),
                  to = c('GATHER',
                         'DETECTIVE_Ph3',
                         'DETECTIVE_Ph2'))
outcome_dat$studysite = as.factor(outcome_dat$studysite)
# changes to database:
outcome_dat$tqmgkgtot[outcome_dat$pid=='KTMTV_13_0870'] = 300/100.7 # error in database
outcome_dat$tqmgkgtot[outcome_dat$pid=='KTMTV_03_0197'] = 300/51.5 # error in database
outcome_dat = outcome_dat[outcome_dat$pid != 'BSAJK_6_219', ] # BSAJK_6_219 vomited but was not re-dosed
outcome_dat$logpara0[is.na(outcome_dat$logpara0)]=3.6 # impute single missing log parasite density with mean value
outcome_dat$pqmgkgtot[is.na(outcome_dat$pqmgkgtot)]=0
outcome_dat$outcome7to120 = outcome_dat$outcome7to180
outcome_dat$outcome7to120[which(outcome_dat$malariaday>127)] = 0

# DEFINITION OF PRIMARY OUTCOME
outcome_dat$outcome_primary = outcome_dat$outcome7to120
max(outcome_dat$tqmgkgtot[which(outcome_dat$outcome_primary==1)])
ind_rm_endpoint_binary = is.na(outcome_dat$malariaday) & outcome_dat$dlast<=30
writeLines(sprintf('%s patients were lost to follow-up before 1 month',sum(ind_rm_endpoint_binary)))
writeLines(sprintf('%s patients were lost to follow-up before 4 months',sum(is.na(outcome_dat$malariaday) & outcome_dat$dlast<105)))
writeLines(sprintf('%s patients were lost to follow-up before 6 months',sum(is.na(outcome_dat$malariaday) & outcome_dat$dlast<164)))
# if less than 1 month follow-up then remove from analysis
outcome_dat$outcome_primary[ind_rm_endpoint_binary]=NA
outcome_dat$outcome7to180[ind_rm_endpoint_binary]=NA



mod0=glmer(outcome7to180 ~ pqmgkgtot + (1|studysite),
           family='binomial', data = outcome_dat[outcome_dat$pqmgkgtot>0, ])
summary(mod0)

mod=glmer(outcome7to180 ~ pqmgkgtot + tqmgkgtot + (1|studysite), family='binomial', data = outcome_dat)
summary(mod)

emax_stan = stan_model(file = 'Emax_logit.stan') # compile model
ind_include = !is.na(outcome_dat$outcome_primary)
sum(ind_include)
pred_x = seq(0,15,length.out=1000)

mod_emax_all =
  sampling(emax_stan,
           data=list(N=sum(ind_include),
                     Ksites = length(unique(outcome_dat$studysite[ind_include])),
                     recurrence = outcome_dat$outcome_primary[ind_include],
                     dose_mg_kg = outcome_dat$tqmgkgtot[ind_include],
                     K_cov = 1,
                     x = matrix(outcome_dat$pqmgkgtot[ind_include],
                                nrow = sum(ind_include)),
                     studysite = as.numeric(outcome_dat$studysite[ind_include]),
                     K=length(pred_x),
                     pred_x = pred_x),
           save_warmup = FALSE)

mypars = c('E0','Emax','ED50','k','pred_y', 'beta')
thetas_all = extract(mod_emax_all, pars=mypars)

ps = invlogit(apply(thetas_all$pred_y,2,mean))
mycols = brewer.pal(n = 12,name = 'Paired')[c(2,6,10)]
layout(mat = matrix(c(1,2,2,2,2),nrow = 5))
par(las=1, cex.lab=1.5, cex.axis=1.5,mar=c(0,5,2,2))
hist(outcome_dat$tqmgkgtot[outcome_dat$pqmgkgtot==0],
     ylab='',xaxt='n',xlab='',yaxt='n',col = brewer.pal(8,'Pastel2')[7],
     main='', breaks = seq(0,15,by=.5))
par(las=1, cex.lab=1.8, cex.axis=1.8,mar=c(6,6,0,2))
plot(pred_x, 100*(ps), lwd=3, type='l',
     xlab = 'Single dose tafenoquine (mg/kg)',col=mycols[1],
     ylab = 'Proportion with P. vivax recurrence (%)',
     ylim = c(0,65), panel.first=grid())
abline(h = 100*invlogit(mean(thetas_all$E0 + 3.5*thetas_all$beta[,1])),lty=1, lwd=2)
polygon(c(-10,-10, 100, 100), 
        100*invlogit(quantile(thetas_all$E0 + 3.5*thetas_all$beta[,1],
                          probs = c(0.025,.975,.975,.025))),
        col = adjustcolor('grey',.3), border = NA)
text(x = 10, y = 18, 'Low-dose primaquine',cex=1.7)

lines(pred_x, 100*(ps), lwd=3, col=mycols[1])
polygon(x = c(pred_x, rev(pred_x)),
        y = 100*invlogit(c(apply(thetas_all$pred_y, 2, quantile, .975),
                  rev(apply(thetas_all$pred_y, 2, quantile, .25)))),
        border = NA, col = adjustcolor(mycols[1], .6))
p0 = ps[1]
p15 = ps[length(pred_x)]


# Max obtainable effect
lines(c(-10, 15), rep(100*p15, 2),lty=2)
lines(c(15, 15), c(-19, 100*p15),lty=2)
text(x = 1.5, y = 100*p15 + 2, 'Emax',cex=1.7)

# E90
x_90 = pred_x[which.min(abs((1-ps/p0) - 0.9*(1-p15/p0)))]
y_90 = ps[which.min(abs((1-ps/p0) - 0.9*(1-p15/p0)))]
lines(c(-10, x_90), rep(100*y_90, 2),lty=2)
lines(c(x_90,x_90), c(-19, 100*y_90),lty=2)
text(x = 1.5, y = 100*y_90 + 2, 'E90',cex=1.7)

# E50
x_50 = pred_x[which.min(abs((1-ps/p0) - 0.5*(1-p15/p0)))]
y_50 = ps[which.min(abs((1-ps/p0) - 0.5*(1-p15/p0)))]
lines(c(-10, x_50), rep(100*y_50, 2),lty=2)
lines(c(x_50,x_50), c(-19, 100*y_50),lty=2)
text(x = 1.5, y = 100*y_50 + 2, 'E50',cex=1.7)




         
         