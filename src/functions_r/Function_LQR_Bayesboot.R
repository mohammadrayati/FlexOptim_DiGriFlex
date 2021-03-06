##### Path of installed packages
R_libraries_path <- "C:/Users/mohammad.rayati/Documents/R/win-library/4.0"
# R_libraries_path <- "C:/Users/labo-reine-iese/Documents/R/win-library/4.0"
.libPaths(c(R_libraries_path))
sink("nul")

##### Load required librarues
library(bayesboot)
library(zoo, warn.conflicts = FALSE)
suppressPackageStartupMessages(library(quantreg))


##### Actual function
LQR_Bayesboot <- function(P_tra,pred_tra,pred_for,h,N_boot) {
  # This function provides a forecast y(t), given data observed until the time interval t-2
  # Output:
  # The output of the function is a [1x1] point prediction obtained from the [9 x N_boot] matrix,
  # containing N_boot bootstrap samples of the 9 predictive quantiles at coverages 0.1,0.2,...,0.9
  
  # Inputs:
  # 1) P_tra and pred_tra are always the same preprocessed training data.
  # 2) pred_for is a data frame containing predictors P(t-144),P(t-2),irra(t-144),irra(t-2)
  # 3) h is the number of the target 10-min interval of the day. E.g., the interval 10:00-10:10 
  #    is the 61th interval of the day; for h<=33 and h>=121 (before 5:30 and after 20:00) 
  #    the output is directly 0.
  # 4) N_boot is the desired number of bootstrap samples. 
  set.seed(h)
  ## ----------------------------- DATA READING AND PREPROCESSING -----------------------------
  # Normalize the inputs 
  base_P <- list("xmin" = min(P_tra), "xmax" = max(P_tra))
  base_irra <- list("xmin" = min(pred_tra[,4]), "xmax" = max(pred_tra[,4]))
  P_tra <- (P_tra-base_P$xmin)/(base_P$xmax-base_P$xmin)
  pred_tra[,1:2] <- (pred_tra[,1:2]-base_P$xmin)/(base_P$xmax-base_P$xmin)
  pred_tra[,3:4] <- (pred_tra[,3:4]-base_irra$xmin)/(base_irra$xmax-base_irra$xmin)

  pred_for[,1:2] <- (pred_for[,1:2]-base_P$xmin)/(base_P$xmax-base_P$xmin)
  pred_for[,3:4] <- (pred_for[,3:4]-base_irra$xmin)/(base_irra$xmax-base_irra$xmin)

  # Store data in a data frame 
  DATA_tra <- data.frame("P"=P_tra,  "Plag144"=pred_tra[,1],"Plag2"=pred_tra[,2],"irralag144"=pred_tra[,3],"irralag2"=pred_tra[,4])
  DATA_for <- data.frame("P_for"=NaN,"Plag144"=pred_for[,1],"Plag2"=pred_for[,2],"irralag144"=pred_for[,3],"irralag2"=pred_for[,4])

  ## ----------------------------- MAKING PREDICTIONS -----------------------------
  Q01 <- seq(0.1,0.9,0.1)
  P_prev <- array(rep(NaN, length(Q01)*N_boot), c(length(Q01),N_boot))
  
  if (h<=33)      # For h<=33 and h>=121 (before 5:30 and after 20:00) the output is directly 0
    {P_prev <- array(rep(0, length(Q01)*N_boot), c(length(Q01),N_boot))}  
  if (h>=121) 
    {P_prev <- array(rep(0, length(Q01)*N_boot), c(length(Q01),N_boot))}  
  if (h>=34 & h <=120) {
    
    # Train and forecast data
    train_h <- seq(from = h, to = length(DATA_tra[,1]), by = 144) 
    DATA_train_h <- DATA_tra[train_h,]
    DATA_forec_h <- DATA_for
    
    # Forecasting model
    for (q in seq(1,length(Q01),1))
    {
      qr_prev <- function(d)     # Definition of the forecasting function (quantile regression model)
      { mdl_fit <- rq( P ~ Plag144 + Plag2 + irralag144 + irralag2 + 
                           Plag144*Plag2 + Plag144*irralag144 + Plag2*irralag2, 
                       tau=Q01[q], data = d)
      predict.rq(mdl_fit, DATA_forec_h) 
      } 
      
      bootstrap_res <- as.matrix( bayesboot(DATA_train_h, qr_prev, R = N_boot) ) # Apply Bayesian bootstrap
      for (n in 1:N_boot)
        {P_prev[q,n] <- bootstrap_res[n,1]}
    }
  }
  
  P_prev[is.nan(P_prev)] <- 0
  P_prev[P_prev < 0] <- 0
  P_prev <- mean(P_prev[5,])   # This line will change after the optimization of the sample pick
  P_prev <-  (base_P$xmin + P_prev * (base_P$xmax - base_P$xmin)) / 1000
}






