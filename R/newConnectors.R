#' Get estimated individual and population parameters
#' 
#' Get the individual individual parameters, the population parameters with the population covariates 
#' and the population parameters with the individual covariates.
#' @return a list of data frames.
#' @examples
#' \dontrun{
#' # Assume that the Monolix project "warfarinPKPD.mlxtran" has been loaded
#' r = getEstimatedIndividualParameters2() 
#' 
#' # r is a list with elements "saem", "conditionalMean", "conditionalSD",   "conditionalMode",
#' # "popPopCov" and "popIndCov"
#' 
#' # See http://rsmlx.webpopix.org/userguide/newconnectors/ for more detailed examples
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' }
#' @export
getEstimatedIndividualParameters2 <- function() {
  
  ind.param <- getEstimatedIndividualParameters()
  N <- nrow(ind.param$saem)
  pop.param <- getEstimatedPopulationParameters()
  pop.param <- pop.param[grep("_pop",names(pop.param))]
  df <- as.data.frame(matrix(pop.param,nrow=N,ncol=length(pop.param),byrow=TRUE))
  names(df) <- gsub("_pop","",names(pop.param))
  ind.param$popPopCov <- data.frame(id=ind.param$saem["id"],df)
  
  rand.eff <- getEstimatedRandomEffects()
  
  if (!is.null(ind.param$conditionalMean)) {
    ip <- ind.param$conditionalMean
    re <- rand.eff$conditionalMean
  } else if (!is.null(ind.param$conditionalMode)) {
    ip <- ind.param$conditionalMode
    re <- rand.eff$conditionalMode
  } else
    stop("The conditional mean or the conditional model should have been computed", call.=FALSE)
  
  ind.dist <- getIndividualParameterModel()$distribution
  var.param <- names(ind.dist)
  ind.param$popIndCov <- ind.param$popPopCov
  for (nj in var.param) {
    dj <- tolower(ind.dist[nj])
    yj <- ip[[nj]]
    rj <- re[[paste0("eta_",nj)]]
    if (dj == "normal") {
      yjc <- yj-rj
    } else if (dj == "lognormal") {
      yjc <- exp(log(yj)-rj)
    } else if (dj == "logitnormal") {
      yjc <- 1/(1+exp(-log(yj/(1-yj))+rj))
    } else if (dj == "probitnormal") {
      yjc <- pnorm(qnorm(yj) - rj)
    } 
    ind.param$popIndCov[nj] <- yjc
  }
  return(ind.param)
}


#--------------------------------------------------------------------

#' Get estimated predictions
#' 
#' Get the individual predictions obtained with the estimated individual parameters :
#' @return a list of data frames (one data frame per output).
#' @examples
#' \dontrun{
#' # Assume that the Monolix project "warfarinPKPD.mlxtran" has been loaded
#' r = getEstimatedPredictions() # r is a list with elements "y1" and "y2"
#' 
#' # See http://rsmlx.webpopix.org/userguide/newconnectors/ for more detailed examples
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' }
#' @export
getEstimatedPredictions <- function() {
  
  ip <- getEstimatedIndividualParameters2()
  
  obs.info <- getObservationInformation()
  
  df <- list()
  nout <- length(obs.info$name)
  for (j in 1:nout) {
    df[j] <- obs.info[obs.info$name[j]]
    df[[j]][obs.info$name[j]] <- NULL
  }
  
  f.pop1 <- computePredictions(ip$popPopCov)
  for (j in 1:nout) {df[[j]]$popPopCov <- f.pop1[[j]]}
  f.pop2 <- computePredictions(ip$popIndCov)
  for (j in 1:nout) {df[[j]]$popIndCov <- f.pop2[[j]]}
  
  if (!is.null(ip$conditionalMean)) {
    f.mean <- computePredictions(ip$conditionalMean)
    for (j in 1:nout) {df[[j]]$conditionalMean <- f.mean[[j]]}
  }
  if (!is.null(ip$conditionalMode)) {
    f.mode <- computePredictions(ip$conditionalMode)
    for (j in 1:nout) {df[[j]]$conditionalMode <- f.mode[[j]]}
  }
  names(df) <- names(f.pop1)
  return(df)
}

#--------------------------------------------------------------------

#' Get estimated residuals
#' 
#' Get the residuals computed from the individual predictions obtained 
#' with the estimated individual parameters:
#' @return a list of data frames (one data frame per output).
#' @examples
#' \dontrun{
#' # Assume that the Monolix project "warfarinPKPD.mlxtran" has been loaded
#' r = getEstimatedResiduals()  # r is a list with elements "y1" and "y2" 
#' 
#' # See http://rsmlx.webpopix.org/userguide/newconnectors/ for more detailed examples
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' }
#' @export
getEstimatedResiduals <- function() {
  
  df=getEstimatedPredictions()
  obs.info <- getObservationInformation()
  nip <- c("popPopCov", "popIndCov", "conditionalMean", "conditionalMode")
  
  nout <- length(obs.info$name)
  error.model <- getContinuousObservationModel()$errorModel
  error.dist <- getContinuousObservationModel()$distribution
  ep <- error.parameter()
  pop.param <- getEstimatedPopulationParameters()
  param.error <- list()
  for (j in 1:nout) {
    dfj <- df[[j]]
    ij <- which(names(dfj) %in% nip)
    nj <- obs.info$name[j]
    yoj <- replicate(length(ij),obs.info[[nj]][[nj]])
    erj <- tolower(error.dist[j])
    if (erj=="normal") {
      ypj <- dfj[,ij]
    } else if (erj=="lognormal") {
      ypj <- log(dfj[,ij])
      yoj <- log(yoj)
    } else if (erj=="logitnormal") {
      limiti <- getContinuousObservationModel()$limits[[names(error.dist)[j]]]
      ypj <- log((dfj[,ij]-limiti[1])/(limiti[2]-dfj[,ij]))
      yoj <- log((yoj-limiti[1])/(limiti[2]-yoj))
    }
    epj <- pop.param[ep[[j]]]
    a <- epj[grep("a", names(epj))]
    if (length(a)==0)  
      a <- 0
    b <- epj[grep("b", names(epj))]
    if (length(b)==0)  
      b <- 0
    c <- epj[grep("c", names(epj))]
    if (length(c)==0)  
      c <- 1
    pei <- c(a, b, c)
    if (error.model[j]=="combined2")
      dfj <- (yoj - ypj)/sqrt(pei[1]^2 + (pei[2]*ypj^pei[3])^2)
    else
      dfj <- (yoj - ypj)/(pei[1] + pei[2]*ypj^pei[3])
    df[[j]] <- dfj
  }
  names(df) <- obs.info$name
  return(df)
}

#--------------------------------------------------------------------
#' Get simulated predictions
#' 
#' Get the individual predictions obtained with the simulated individual parameters :
#' @return a list of data frames (one data frame per output).
#' @examples
#' \dontrun{
#' # Assume that the Monolix project "warfarinPKPD.mlxtran" has been loaded
#' r = getSimulatedPredictions()  # r is a list with elements "Cc" and "E" 
#' 
#' # See http://rsmlx.webpopix.org/userguide/newconnectors/ for more detailed examples
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' }
#' @export
getSimulatedPredictions <- function() {
  
  sip <- getSimulatedIndividualParameters()
  if (is.null(sip$rep)) 
    sip$rep <- 1
  nrep <- max(sip$rep)
  
  obs.info <- getObservationInformation()
  df <- list()
  nout <- length(obs.info$name)
  pred <- getContinuousObservationModel()$prediction
  for (j in 1:nout) {
    df[j] <- obs.info[obs.info$name[j]]
    df[[j]][obs.info$name[j]] <- NULL
    df[[j]][pred[j]] <- 0
    df[[j]] <- cbind(rep=1, df[[j]])
  }
  
  col.el <- which(!(names(sip) %in% c("rep","id")))
  res <- list()
  for (irep in (1:nrep)) {
    parami <- subset(sip, rep==irep)[,col.el]
    fi <- computePredictions(parami)
    for (j in 1:nout) {
      df[[j]][pred[j]] <- fi[[j]]
      df[[j]]["rep"] <- irep
      if (irep==1)
        res[[j]] <- df[[j]]
      else
        res[[j]] <- rbind(res[[j]], df[[j]])
    }
    
  }
  names(res) <- pred
  return(res)
}

#--------------------------------------------------------------------
#' Get simulated residuals
#' 
#' Get the residuals computed from the individual predictions obtained 
#' with the simulated individual parameters:
#' @return a list of data frames (one data frame per output).
#' @examples
#' \dontrun{
#' # Assume that the Monolix project "warfarinPKPD.mlxtran" has been loaded
#' r = getSimulatedResiduals()  # r is a list with elements "y1" and "y2" 
#' 
#' # See http://rsmlx.webpopix.org/userguide/newconnectors/ for more detailed examples
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' }
#' @export
getSimulatedResiduals <- function() {
  
  df=getSimulatedPredictions()
  obs.info <- getObservationInformation()

  nout <- length(obs.info$name)
  error.model <- getContinuousObservationModel()$errorModel
  error.dist <- getContinuousObservationModel()$distribution
  ep <- error.parameter()
  pop.param <- getEstimatedPopulationParameters()
  param.error <- list()
  nrep <- max(df[[1]]["rep"])
  for (j in 1:nout) {
    dfj <- df[[j]]
    ij <- which(names(dfj) == names(df)[j])
    nj <- obs.info$name[j]
    yoj <- rep(obs.info[[nj]][[nj]],nrep)
    erj <- tolower(error.dist[j])
    if (erj=="normal") {
      ypj <- dfj[,ij]
    } else if (erj=="lognormal") {
      ypj <- log(dfj[,ij])
      yoj <- log(yoj)
    } else if (erj=="logitnormal") {
      limiti <- getContinuousObservationModel()$limits[[names(error.dist)[j]]]
      ypj <- log((dfj[,ij]-limiti[1])/(limiti[2]-dfj[,ij]))
      yoj <- log((yoj-limiti[1])/(limiti[2]-yoj))
    }
    epj <- pop.param[ep[[j]]]
    a <- epj[grep("a", names(epj))]
    if (length(a)==0)  
      a <- 0
    b <- epj[grep("b", names(epj))]
    if (length(b)==0)  
      b <- 0
    c <- epj[grep("c", names(epj))]
    if (length(c)==0)  
      c <- 1
    pei <- c(a, b, c)
    if (error.model[j]=="combined2")
      dfj <- (yoj - ypj)/sqrt(pei[1]^2 + (pei[2]*ypj^pei[3])^2)
    else
      dfj <- (yoj - ypj)/(pei[1] + pei[2]*ypj^pei[3])
    df[[j]][,ij] <- dfj
    names(df[[j]])[ij] <- "residual"
  }
  names(df) <- obs.info$name
  return(df)
}

#--------------------------------------------------------------------
#' Get estimated covariance and correlation matrices
#' 
#' @return a list of two matrices.
#' @examples
#' \dontrun{
#' # Assume that the Monolix project "warfarinPKPD.mlxtran" has been loaded
#' r = GetEstimatedCovarianceMatrix()  # r is a list with elements "cor.matrix" and "cov.matrix"
#' 
#' # See http://rsmlx.webpopix.org/userguide/newconnectors/ for more detailed examples
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' }
#' @export
GetEstimatedCovarianceMatrix <- function() {
  param <- getEstimatedPopulationParameters()
  pname <- names(param)
  i.omega <- grep("^omega_",pname)
  if (length(i.omega)>0) {
    oest <- 1
    oname <- gsub("^omega_","",pname[i.omega])
    omega <- param[i.omega]
  } else {
    i.omega <- grep("^omega2_",pname)
    oname <- gsub("^omega2_","",pname[i.omega])
    omega <- sqrt(param[i.omega])
    oest <- 2
  }
  i.corr <- grep("^corr_",pname)
  d <- length(i.omega)
  c <- param[i.corr]
  R <- diag(rep(1,d))
  rownames(R) <- colnames(R) <- oname
  for (j in 1:length(c)) {
    cj <- names(c)[j]
    sj <- strsplit(cj,"_")[[1]]
    R[sj[3],sj[2]] <- R[sj[2],sj[3]] <- c[j]
  }
  C <- diag(omega)%*%R%*%diag(omega)
  return(list(cor.matrix=R, cov.matrix=C))
}

#--------------------------------------------------------------------
error.parameter <- function(project=NULL) {
  if (is.null(project)) {
    dp <- getProjectSettings()$directory
    if (!is.null(dp))
    project <- paste0(dp,".mlxtran")
#    project <- paste0(basename(dp),".mlxtran")
  }
  if (!file.exists(project)) 
    stop("Enter a valid project", call.=FALSE)
  
  con        = file(project, open = "r")
  lines      = readLines(con, warn=FALSE)
  close(con)
  lines <- lines[grep("errorModel", lines)]
  r <- list()
  if (length(lines)>0) {
    lines <- gsub(" ","",lines)
    for (k in (1: length(lines))) {
      lk <- lines[k]
      i1 <- regexpr("\\(",lk)
      i2 <- regexpr("\\)",lk)
      r[[k]] <- strsplit(substr(lk,(i1+1),(i2-1)),",")[[1]]
    }
  }
  return(r)
}


prcheck <- function(project, f=NULL, settings=NULL, model=NULL, paramToUse=NULL,
                    parameters=NULL, level=NULL, tests=NULL, nboot=NULL, method=NULL) {
  #prcheck <- function(project) {
  if (identical(substr(project,1,9),"RsmlxDemo")) {
    RsmlxDemo1.project <- RsmlxDemo2.project <- warfarin.data  <- resMonolix <- NULL
    rm(RsmlxDemo1.project, RsmlxDemo2.project, warfarin.data, resMonolix)
    eval(parse(text="data(RsmlxDemo)"))
    tmp.dir <- tempdir()
    write(RsmlxDemo1.project, file=file.path(tmp.dir,"RsmlxDemo1.mlxtran"))
    write(RsmlxDemo2.project, file=file.path(tmp.dir,"RsmlxDemo2.mlxtran"))
    write.csv(warfarin.data, file=file.path(tmp.dir,"warfarin_data.csv"), quote=FALSE, row.names = FALSE)
    project <- file.path(tmp.dir,project)
    demo <- TRUE
    if (!is.null(f)) {
      if (f=="boot") {
        if (is.null(settings))
          res <- resMonolix$r1.boot
        else if (!is.null(settings$N) & is.null(settings$covStrat))
          res <- resMonolix$r2.boot
        else
          res <- resMonolix$r3.boot
      } else if (f=="build") {
        if (identical(model,"all") & identical(paramToUse,"all")) 
          res <- resMonolix$r1.build
        else if (identical(model,"all")) 
          res <- resMonolix$r2.build
        else 
          res <- resMonolix$r3.build
      } else if (f=="conf") {
        if (method == "fim" & level==0.90)
          res <- resMonolix$r1.conf
        else if (method == "fim" & level==0.95)
          res <- resMonolix$r2.conf
        else if (method == "proflike")
          res <- resMonolix$r3.conf
        else
          res <- resMonolix$r4.conf
      } else if (f=="cov") {
        if (identical(method,"COSSAC") & identical(paramToUse,"all")) 
          res <- resMonolix$r1.cov
        else if (identical(method,"SCM")) 
          res <- resMonolix$r2.cov
        else 
          res <- resMonolix$r3.cov
      } else if (f=="test") {
        if (length(tests)==4) 
          res <- resMonolix$r1.test
        else 
          res <- resMonolix$r2.test
      } else if (f=="set")
        res="foo"
    }
    
  } else {
    
    if (!grepl("\\.",project))
      project <- paste0(project,".mlxtran")
    
    if(!file.exists(project))
      stop(paste0("Project '", project, "' does not exist"), call.=FALSE)
    
    lp <- loadProject(project) 
    if (!lp) 
      stop(paste0("Could not load project '", project, "'"), call.=FALSE)
    
    demo <- FALSE
    res <- NULL
  }
  
  return(list(project=project, demo=demo, res=res))
  #  return(project)
}

# prepare.demo <- function() {
#   setwd("F:/modelBuilding/git/Rsmlx/inst/extdata")
#   con = file("RsmlxDemo1.mlxtran", open = "r")
#   RsmlxDemo1.project = readLines(con, warn=FALSE)
#   close(con)
#   con = file("RsmlxDemo2.mlxtran", open = "r")
#   RsmlxDemo2.project = readLines(con, warn=FALSE)
#   close(con)
#   warfarin.data <- read.csv(file="warfarin_data.csv")
#   setwd("F:/modelBuilding/git/Rsmlx/data")
#   save(RsmlxDemo1.project, RsmlxDemo2.project, warfarin.data, file="RsmlxDemo.RData" )
# }





