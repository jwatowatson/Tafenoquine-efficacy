library(haven)
outcome_dat = read_dta('an1_tq_efficacy.dta')
outcome_dat$study =
  plyr::mapvalues(outcome_dat$sid,
                  from = c('BSAJK',
                           'KTMTV',
                           'PRSXC'),
                  to = c('GATHER',
                         'DETECTIVE_Ph3',
                         'DETECTIVE_Ph2'))
table(outcome_dat$study)
outcome_dat$studysite = as.factor(outcome_dat$studysite)

# changes to database:
outcome_dat$tqmgkgtot[outcome_dat$pid=='KTMTV_13_0870'] = 300/100.7 # error in database
outcome_dat$tqmgkgtot[outcome_dat$pid=='KTMTV_03_0197'] = 300/51.5 # error in database
outcome_dat = outcome_dat[outcome_dat$pid != 'BSAJK_6_219', ] # BSAJK_6_219 vomited but was not re-dosed
outcome_dat = outcome_dat[!is.na(outcome_dat$logpara0), ] # PRSXC_04_0276 had neg parasitaemia at enrolment
outcome_dat$pqmgkgtot[outcome_dat$pid=='KTMTV_13_0020'] = 14*15/72.3

outcome_dat$pqmgkgtot[is.na(outcome_dat$pqmgkgtot)]=0
outcome_dat$AMT = paste0('TQ', round(outcome_dat$weight*outcome_dat$tqmgkgtot))
outcome_dat$AMT[outcome_dat$pqmgkgtot>0] = 'PQ15'
outcome_dat$AMT[outcome_dat$AMT=='TQ0'] = 'No Radical Cure'
writeLines('TQ doses in efficacy analyses:')
table(outcome_dat$AMT)
# 
# # Define the sensitivity analysis subgroup (300 mg dose)
# ind_sensitivity = outcome_dat$AMT == 'TQ300'
# sum(ind_sensitivity)
# 
outcome_dat$outcome7to120 = outcome_dat$outcome7to180
outcome_dat$outcome7to120[which(outcome_dat$malariaday>127)] = 0
# 
# # DEFINITION OF PRIMARY OUTCOME
outcome_dat$outcome_primary = outcome_dat$outcome7to120
max(outcome_dat$tqmgkgtot[which(outcome_dat$outcome_primary==1)])
max(outcome_dat$pqmgkgtot[which(outcome_dat$outcome_primary==1)])


# # load the NONMEM output t_12
dat2=read.csv('../../Tafenoquine_PK_datsets/Results TQ James_M3.csv')
# 

# load all PK data - stored in NONMEM format so needs some reformatting
pk=readr::read_csv('../../Tafenoquine_PK_datsets/All_TQ_PK_data.csv',na = '.')[-1, ]
pk$TIME = as.numeric(pk$TIME)/24
pk$ODV = as.numeric(pk$ODV)
pk$BW = as.numeric(pk$BW)
pk$ODV[which(pk$BLQ==1)]=2
pk$AMT = as.numeric(pk$AMT)
pk$dose_tq=NA
for(id in unique(pk$PID)){
  ind = pk$PID==id
  pk$dose_tq[ind]= unique(pk$AMT[!is.na(pk$AMT) & ind])/pk$BW[ind][1]
}

# use data after day 7
pk = pk[pk$TIME>=4 & !is.na(pk$ODV), ]
plot(pk$TIME, log10(pk$ODV))
hist(table(pk$PID))
quantile(table(pk$PID))

library(brms)
pk$censor = 'none'
pk$censor[pk$BLQ==1] = 'left'
pk$log_BW = log(pk$BW)

# mod_cens = brm(log(ODV) | cens(censor) ~ 1+TIME*log_BW-log_BW+VOMIT+dose_tq+(1+TIME|PID),
#                data = pk, family = 'student', cores = 4, chains = 4,
#                iter = 4000,
#                prior = c(prior(lkj(2), class = "cor"),
#                          prior(normal(5, 5), class = Intercept),
#                          prior(normal(0, 2), class = 'b'),
#                          prior(constant(10), class = 'nu'),
#                          prior(cauchy(0, 1),  class = 'sigma')))
# save(mod_cens, file = 'Rout/mod_cens_brms.RData')
load(file = 'Rout/mod_cens_brms.RData')

# plot(mod_cens)

preds_all = posterior_predict(mod_cens)
ind=pk$censor=='none'
plot(pk$TIME[ind], log(pk$ODV[ind])-colMeans(preds_all)[ind], xlim = c(0,100))

ind_dup = !duplicated(pk$PID)
pred_dat = rbind(cbind(pk[ind_dup,c('PID','log_BW','dose_tq','VOMIT')], TIME=14),
                 cbind(pk[ind_dup,c('PID','log_BW','dose_tq','VOMIT')], TIME=100))
xx=colMeans(posterior_predict(mod_cens, newdata = pred_dat))


# compute half lives from model
IDs = unique(pk$PID)
N = length(IDs)
t12_summary = array(dim = c(N, 2))

for(i in 1:N){
  ind = which(pred_dat$PID==IDs[i])
  t12_summary[i, ] = c(IDs[i], coef(lm(xx[ind] ~ pred_dat$TIME[ind]))[2])
}
colnames(t12_summary)=c('ID', 'slope')
t12_summary = as.data.frame(t12_summary)
t12_summary$t_12 = -log(2)/as.numeric(t12_summary$slope)
hist(t12_summary$t_12,breaks = 20)

ids = t12_summary$ID[t12_summary$t_12>30]
par(mfrow=c(2,2))
plot(pk$TIME, log10(pk$ODV))
for(id in ids){
  ind = pk$PID==id
  plot(pk$TIME[ind], log10(pk$ODV[ind]), xlim=range(pk$TIME),
       ylim = range(log10(pk$ODV)))
  abline(v=14)
}

# extract NONMEM output half lives
dat2$t_12_NONMEM=NA
dat2$PID = NA
for(i in 1:nrow(dat2)){
  if(dat2$ID[i] %in% pk$`#ID`){
    bw = unique(pk$BW[pk$`#ID`==dat2$ID[i]])
    dat2$PID[i] = unique(pk$PID[pk$`#ID`==dat2$ID[i]])
    dat2$t_12_NONMEM[i] =
      clinPK::pk_2cmt_t12(CL = dat2$CL[i],
                          V = dat2$V2[i],
                          Q = dat2$Q1[i],
                          V2 = dat2$V3[i])$beta/24
  }
}

outcome_dat = merge(outcome_dat, dat2, by.x = 'pid', by.y='PID')
outcome_dat = merge(outcome_dat, t12_summary, by.x = 'pid', by.y='ID')

plot(outcome_dat$t_12_NONMEM, outcome_dat$t_12)

library(lme4)
summary(glmer(outcome_primary ~ t_12 + tqmgkgtot + (1|studysite),
              family='binomial', data = outcome_dat))

summary(glmer(outcome_primary ~ t_12_NONMEM + tqmgkgtot + (1|studysite), 
              family='binomial', data = outcome_dat))


pdf('../../Tafenoquine_PK_datsets/comparison_half_lives.pdf',width = 8, height = 8)
quantile(table(pk$`#ID`))
median(outcome_dat$t_12, na.rm = T)
median(outcome_dat$t_12_NONMEM, na.rm = T)

par(mfrow=c(2,2),las=1)
hist(outcome_dat$t_12, xlab='Naive model: t_12',main='', breaks=seq(5, 50, by=2))
hist(outcome_dat$t_12_NONMEM, xlab='NONMEM: t_12',main='',breaks=seq(5, 50, by=2))

plot(outcome_dat$t_12, outcome_dat$t_12_NONMEM,
     xlab='Naive model: t_12', ylab='NONMEM: t_12',
     pch = 1+15*outcome_dat$outcome7to120,panel.first=grid(),
     col = outcome_dat$outcome7to120+1)
lines(0:50, 0:50)
# 
plot(outcome_dat$t_12, outcome_dat$t_12-outcome_dat$t_12_NONMEM,
     pch = 1+15*outcome_dat$outcome7to120,panel.first=grid(),
     xlab='Naive model: t_12', ylab = 'difference in t_12 (naive-NONMEM)',
     col = outcome_dat$outcome7to120+1)
abline(h=c(-3.5, 0, 2.5))

ids_outlier = outcome_dat$pid[!is.na(outcome_dat$t_12) &
                                ((outcome_dat$t_12-outcome_dat$t_12_NONMEM)>2.5 |
                                   (outcome_dat$t_12-outcome_dat$t_12_NONMEM) < -3.5) ]
par(mfrow=c(2,2), mar=c(2,5,3,1),las=1)
for(id in ids_outlier){
  ind = pk$PID==id
  plot(pk$TIME[ind], log(pk$ODV[ind]), xlim=c(0, 150),
       ylim = c(log(2), 6),pch=16+pk$BLQ[ind], cex=1.5,panel.first=grid(),
       xlab='', ylab ='', col='red',yaxt='n',main=id)
  axis(2, at = log(c(3,10,30,100,300)), labels = c(3,10,30,100,300))
  lines(pk$TIME[ind], colMeans(preds_all[,ind]),lwd=3, lty=2)
  polygon(c(pk$TIME[ind], rev(pk$TIME[ind])),
          c(apply(preds_all[,ind],2,quantile,prob=0.1),
            rev(apply(preds_all[,ind],2,quantile,prob=0.9))),border = NA,
          col = adjustcolor('grey',.4))
  text(x = 70, y = 5, paste('Naive: ',round(outcome_dat$t_12[outcome_dat$pid==id],1),'\n',
                            'NONMEM: ',round(outcome_dat$t_12_NONMEM[outcome_dat$pid==id],1)),
       cex=1.2)
}

dev.off()

t12_summary = outcome_dat[, c('pid', 't_12_NONMEM')]


save(t12_summary, file = 'Rout/t12.Rdata')


