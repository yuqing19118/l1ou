#'
#' computes the bootstrap support for the detected shift positions
#'
#'@param tr The input phylogeny.
#'@param model It contains estimated shift positions and also the input configuration. You may want to change model$opt to run with different options.
#'@param nItrs Maximum number of shifts; The default value is half the number of tips.
#'@param multicore If TRUE, it runs nCores processes in parallel. See details. 
#'@param nCores The desire number of parallel process.
#'@return detection rate vector.
#'
#'@details The results of sequential and parellel runs are not necessarly equal.
#'
#'@examples
#' 
#' library("l1ou"); 
#' data("lizardTraits", "lizardTree");
#' Y      <- lizard.traits[,1]; 
#' eModel <- estimate_shift_configuration(lizard.tree, Y);
#' res    <- bootstrap_support(lizard.tree, eModel, nItrs=2);
#' print(res);
#'
#'@export
bootstrap_support <- function(tr, model, nItrs=100, multicore=FALSE, nCores = 2){

    if(multicore){
        library("parallel");
    }

    if(ncol(model$Y)==1){
        return(bootstrap_support_univariate(tr=tr, model=model, nItrs=nItrs, multicore=multicore, nCores=nCores));
    }
    if(ncol(model$Y)>1){
        return(bootstrap_support_multivariate(tr=tr, model=model, nItrs=nItrs, multicore=multicore, nCores=nCores));
    }
}

bootstrap_support_univariate <- function(tr, model, nItrs, multicore=FALSE, nCores=2){

    RE    = sqrt_OU_covariance(tr, alpha=model$alpha);

    C.IH  = t(RE$D);
    C.H   = RE$B;

    Y     = model$Y;
    YY    = C.IH%*%(Y - model$mu );

    detection.vec = rep(0, nrow(tr$edge));

    if(multicore == FALSE){
        for(itr in 1:nItrs){
            YYstar = sample(YY, replace = TRUE);
            Ystar  = (C.H%*%YYstar) + model$mu; 
            eM     = estimate_shift_configuration(tr, Ystar, l1ou.options = model$l1ou.options);
            detection.vec[eM$shift.configuration] = detection.vec[eM$shift.configuration] + 1;
        }
        return(detection.vec/nItrs);
    }

    shift.configuration.list = 
        mclapply(X=1:nItrs, FUN=function(itr){

                     set.seed( 101 + itr);
                     YYstar = sample(YY, replace = TRUE);
                     Ystar  = (C.H%*%YYstar) + model$mu ; 

                     eM  <-  tryCatch({
                         estimate_shift_configuration(tr, Ystar, l1ou.options =model$l1ou.options);
                     }, error = function(e) {
                         print("l1OU error, return NA");
                         return(NA); }  );

                     if(all(is.na(eM))) {return(NA);}
                     return(eM$shift.configuration);
           }, mc.cores = nCores);

    valid.count <- 0;
    for( i in 1:length(shift.configuration.list)){
        if( all(is.na( shift.configuration.list[[i]] )) ){
            next;
        }
        valid.count <- valid.count + 1;
        detection.vec[ shift.configuration.list[[i]] ] = 
            detection.vec[ shift.configuration.list[[i]] ] + 1;
    }

    return(detection.vec/valid.count);
}

bootstrap_support_multivariate <- function(tr, model, nItrs, multicore=FALSE, nCores=2){

    Y = as.matrix(model$Y);
    stopifnot( length(model$alpha) == ncol(Y) );

    YY        = Y;
    C.Hlist   = list();
    for( idx in 1:ncol(Y) ){
        RE    = sqrt_OU_covariance(tr, alpha = model$alpha[[idx]] ); 
        C.IH  = t(RE$D); 
        C.Hlist[[idx]] = RE$B;
        YY[, idx]      = C.IH%*%(Y[, idx] - model$mu[ ,idx]);
    }

    detection.vec = rep(0, nrow(tr$edge));

    if( multicore == FALSE ){
        for(itr in 1:nItrs){

            Ystar   = YY;
            idx.vec = sample(1:nrow(YY), replace = TRUE);
            for( idx in 1:ncol(YY) ){
                YYstar        = YY[idx.vec, idx];
                Ystar[, idx]  = (C.Hlist[[idx]] %*% YYstar) + model$mu[, idx]; 
            }
            eM  <-  tryCatch({
                estimate_shift_configuration(tr, Ystar,  l1ou.options=model$l1ou.options);
            }, error = function(e) {
                print("l1OU error, return NA");
                return(NA); }  );

            if(all(is.na(eM))) {next;}
            detection.vec[eM$shift.configuration] = detection.vec[eM$shift.configuration] + 1;
        }
    }

    shift.configuration.list = 
        mclapply(X=1:nItrs, FUN=function(itr){
                     Ystar   = YY;
                     set.seed( 101 + itr);
                     idx.vec = sample(1:nrow(YY), replace = TRUE);
                     for( idx in 1:ncol(YY) ){
                         YYstar        = YY[idx.vec, idx];
                         Ystar[, idx]  = (C.Hlist[[idx]] %*% YYstar) + model$mu[, idx]; 
                     }
                     eM  <-  tryCatch({
                         estimate_shift_configuration(tr, Ystar, l1ou.options = model$l1ou.options);
                     }, error = function(e) {
                         print("l1OU error, return NA");
                         return(NA); }  );

                     if(all(is.na(eM))) {return(NA);}
                     return(eM$shift.configuration);
                }, mc.cores = nCores);

    valid.count <- 0;
    for( i in 1:length(shift.configuration.list)){
        if( all(is.na( shift.configuration.list[[i]] )) ){
            next;
        }
        valid.count <- valid.count + 1;
        detection.vec[ shift.configuration.list[[i]] ] = 
            detection.vec[ shift.configuration.list[[i]] ] + 1;
    }

    return(detection.vec/valid.count);
}