#' Bootstrapping - case resampling
#'
#' Generate replicates of the original data using random sampling with replacement.
#' Population parameters are then estimated from each replicate.
#' @param project Monolix project 
#' @param nboot [optional] number of bootstrap replicates (default=100)
#' @param dataFolder [optional] folder where already generated datasets are stored, e.g dataFolder="./dummy_project/boot/" (default: data set are generated by bootmlx)
#' @param settings [optional] a list of settings for the resampling and the results:
#' \itemize{
#' \item \code{N} the number of individuals in each bootstrap data set 
#' (default value is the  number of individuals in the original data set).
#' \item \code{newResampling} boolean to generate the data sets again if they already exist (default=FALSE).
#' \item \code{covStrat} a categorical covariate of the project. The original distribution of this covariate
#' is maintained in each resampled data set if covStrat is defined (default=NULL). Notice that if the categorical covariate is varying 
#' within the subject (in case of IOV), it will not be taken into account.
#' \item \code{plot} boolean to choose if the distribution of the bootstraped esimates is displayed
#' (default = TRUE)
#' \item \code{level} level of the bootstrap confidence intervals of the population parameters
#' (default = 0.90)
#' }
#' @return a data frame with the bootstrap estimates
#' @examples
#' initializeMlxConnectors(software = "monolix")
#' 
#' # RsmlxDemo1.mlxtran is a Monolix project for modelling the PK of warfarin using a PK model 
#' # with parameters ka, V, Cl.
#' 
#' # In this example, bootmlx will generate 100 random replicates of the original data and will
#' # use Monolix to estimate the population parameters from each of these 100 replicates:
#' r1 <- bootmlx(project="RsmlxDemo1.mlxtran")
#'   
#' # 5 replicates will now be generated, with 50 individuals in each replicate:
#' r2 <- bootmlx(project="RsmlxDemo1.mlxtran",  nboot = 5, settings = list(N = 50))
#' 
#' # Proportions of males and females in the original dataset will be preserved   
#' # in each replicate:
#' r3 <- bootmlx(project="RsmlxDemo1.mlxtran",  settings = list(covStrat = "sex"))
#' 
#' # See http://rsmlx.webpopix.org/userguide/bootmlx/ for detailed examples of use of bootmlx
#' # Download the demo examples here: http://rsmlx.webpopix.org/Rsmlx/Rsmlx10_demos.zip
#' @importFrom graphics boxplot lines par plot
#' @importFrom stats quantile
#' @export
bootmlx <- function(project, nboot = 100, dataFolder = NULL, settings = NULL){
  
  #r <- prcheck(project, f="boot", settings=settings)
  #if (r$demo)
  #  return(r$res)
  #project <- r$project
  
  loadProject(project)
  exportDir <- getProjectSettings()$directory
  projectName <- substr(basename(project), 1, nchar(basename(project))-8)
  
  # Check and initialize the settings
  if(!is.null(settings)){
    if(!.checkBootstrapInput(inputName = "settings", inputValue = settings)){return(invisible(FALSE))}
  }
  # Check and initialize the settings
  if(!.checkBootstrapInput(inputName = "nboot", inputValue = nboot)){return(invisible(FALSE))}
  if(is.null(settings$plot)){ plot.res <- TRUE }else{ plot.res <- settings$plot; settings$plot<- NULL}
  if(is.null(settings$level)){ level <- 0.90 }else{ level <- settings$level; settings$level<- NULL}
  settings$nboot <- nboot
  if(is.null(settings$nboot)){ settings$nboot <- 100 }
  if(is.null(settings$N)){ settings$N <- NA}
  if(is.null(settings$newResampling)){ settings$newResampling <- FALSE}
  if(is.null(settings$covStrat)){settings$covStrat <- NA}
  
  if(!is.null(dataFolder)){
    if(!(nboot==100)){
      message("WARNING: Both dataFolder and nBoot can not be used both at the same time")
      return(invisible(FALSE))
    }
    dataFiles <- list.files(path = dataFolder, pattern = '*.txt|*.csv')
    if(length(dataFiles)>0){
      settings$nboot <- length(dataFiles)
      settings$newResampling <- FALSE
    }else{
      message("WARNING: Folder ",dataFolder,' does not exist or does not contain any data set')
      return(invisible(FALSE))
    }
  }else{
    #dataFolder <- paste0(exportDir,'/bootstrap/')
  }
  
  # Prepare all the output folders
  param <- getPopulationParameterInformation()$name[which(getPopulationParameterInformation()$method!="FIXED")]
  
  if(settings$newResampling){
    cleanbootstrap(project)
  }
  
  if(is.null(dataFolder)){
    generateBootstrap(project=project, settings=settings)
  }else{
    generateBootstrap(project=project, settings=settings, dataFolder=dataFolder)
  }
  
  #paramResults <- array(dim = c(settings$nboot, length(param))) 
  paramResults <- NULL 
  for(indexSample in 1:settings$nboot){
    projectBoot <-  paste0(exportDir,'/bootstrap/',projectName,'_bootstrap_',toString(indexSample),'.mlxtran')
    loadProject(projectBoot)
    cat(paste0('Project ',toString(indexSample),'/',toString(settings$nboot)))
    
    # Check if the run was done
   # if(!file.exists(paste0(getProjectSettings()$directory,'/populationParameters.txt'))){
      launched.tasks <- getLaunchedTasks()
      if (!launched.tasks[["populationParameterEstimation"]]) {
        cat(' => Running SAEM \n')
      runScenario()
    }else{
      cat(' => already computed \n')
    }
    paramResults <-  rbind(paramResults, getEstimatedPopulationParameters())
  }
  colnames(paramResults) <- names(getEstimatedPopulationParameters())
  paramResults <- as.data.frame(paramResults)
  
  
  # Plot the results
  if (plot.res) {
    nbFig <- ncol(paramResults)
    x_NbFig <- ceiling(max(sqrt(nbFig),1)); y_NbFig <- ceiling(nbFig/x_NbFig)
    par(mfrow = c(x_NbFig, y_NbFig), oma = c(0, 3, 1, 1), mar = c(3, 1, 0, 3), mgp = c(1, 1, 0), xpd = NA)
    for(indexFigure in 1:nbFig){
      res <- paramResults[,indexFigure]
      resQ <- quantile(res,c((1-level)/2,(1+level)/2))
      bxp <- boxplot(res, xlab = paste0(colnames(paramResults)[indexFigure],'\n',level*100,'% CI: [',toString(round(resQ[1],3)),', ',toString(round(resQ[2],3)),']'))
    }
  }
  #res.file <- paste0(exportDir,'/bootstrap/',projectName,'bootstrapResults.txt')
  res.file <- file.path(exportDir,"bootstrap","populationParameters.txt")
  write.table(x = paramResults, file = res.file,
              eol = "\n", sep = ",", col.names = TRUE, quote = FALSE, row.names = FALSE)
  return(paramResults)
}

##################################################################################################################
# Generate the projects and the data set
##################################################################################################################
generateBootstrap = function(project, dataFolder=NULL, settings=NULL){
  
  if(!file.exists(project)){
    message(paste0("ERROR: project '", project, "' does not exist"))
    return(invisible(FALSE))}
  
  loadProject(project)   
  
  if(is.null(settings)){
        settings$nboot <- 100 
        settings$N <- NA
        settings$covStrat <- NA
  }
  
  # define the scenario in order to only have SAEM
  setScenario(tasks =  c(populationParameterEstimation = TRUE))
  
  # Prepare all the output folders
  exportDir <- getProjectSettings()$directory
  projectName <- substr(basename(project), 1, nchar(basename(project))-8)
  dir.create(file.path(exportDir, 'bootstrap/'), showWarnings = FALSE, recursive = TRUE)
  
  # Get the data set information
  referenceDataset <- getData()
  cov <- getCovariateInformation()
  datasetFile <- referenceDataset$dataFile
  
  if(is.null(dataFolder)){
    cat("Generating data sets...\n")
    dir.create(file.path(exportDir, 'bootstrap/data/'), showWarnings = FALSE)
    
    # Load the data set
    dataset <- NULL
    try(dataset <- read.table(file=datasetFile, header = TRUE, sep = ";", dec = "."), silent = TRUE);sepBoot = ';';
    if(length(dataset[1,])<=1){try(dataset <- read.table(file=datasetFile, header = TRUE, sep = ",", dec = "."), silent = TRUE);sepBoot = ',';}
    if(length(dataset[1,])<=1){try(dataset <- read.table(file=datasetFile, header = TRUE, sep = "\t", dec = "."), silent = TRUE);sepBoot = '\t';}
    if(length(dataset[1,])<=1){try(dataset <- read.table(file=datasetFile, header = TRUE, sep = "", dec = "."), silent = TRUE);sepBoot = ' ';}
    if(length(dataset[1,])<=1){      
      message("WARNING: The data set can not be recognized")
      return(invisible(FALSE))}
  
    indexID <- which(referenceDataset$headerTypes=="id")
    nameID <- unique(dataset[, indexID])
    nbIndiv <- length(nameID)
    if(is.na(settings[['N']])){settings[['N']] = nbIndiv}
    
    validID <- list()
    
    if(is.na(settings$covStrat)){
      nbCAT = 1
      indexPropCAT <- 1
      propCAT <- rep(settings[['N']], nbCAT)
      validID[[indexPropCAT]] <- nameID
    }else{
      indexCAT <- which(names(cov$covariate) == settings$covStrat)
      
      isCatVaryID <- F
      for(indexIDtestCAT in 1:length(nameID)){
        cat <- cov$covariate[which(cov$covariate[,1]==nameID[indexIDtestCAT]),indexCAT]
        if(length(unique(cat))>1){
          isCatVaryID <- T
        }
      }
      
      if(isCatVaryID){# The covariate vary within the subject occasion, 
        cat(paste0("The generated data set can not preserve proportions of ", settings$covStrat," as the covariate vary in within the subject.\n"))
        nbCAT = 1
        indexPropCAT <- 1
        propCAT <- rep(settings[['N']], nbCAT)
        validID[[indexPropCAT]] <- nameID
      }else{
        catValues <- cov$covariate[,indexCAT]
        nameCAT <- unique(catValues)
        nbCAT <- length(nameCAT)
        propCAT <- rep(settings[['N']], nbCAT)
        validID <- list()
        for(indexPropCAT in 1:nbCAT){
          indexIdCat <- which(catValues==nameCAT[indexPropCAT])
          propCAT[indexPropCAT] <- max(1,floor(settings[['N']]*length(indexIdCat)/nbIndiv))
          validID[[indexPropCAT]] <- as.character(cov$covariate[indexIdCat,1])
        }
      }
    }
    cat("Generating projects with bootstrap data sets...\n")
    warningAlreadyDisplayed <- F
    
    for(indexSample in 1:settings$nboot){
      datasetFileName <- paste0(exportDir,'/bootstrap/data/dataset_',toString(indexSample),'.csv')
      if(!file.exists(datasetFileName)){
        ##################################################################################################################
        # Generate the data set
        ##################################################################################################################
        # Sample the IDs
        sampleIDs <- NULL
        for(indexValidID in 1:length(validID)){
          if(length(validID[[indexValidID]])==1){
              sampleIDs <- c(sampleIDs,  rep(x = validID[[indexValidID]], times = propCAT[indexValidID]) )
          }else{
              samples <- NULL
              samples <- sample(x = validID[[indexValidID]], size = propCAT[indexValidID], replace = TRUE)
              sampleIDs <- c(sampleIDs, as.character(samples))
          }
        }
        if(!(length(sampleIDs)==settings[['N']])){
          if(!warningAlreadyDisplayed){
            cat(paste0("The generated data set contains only ",length(sampleIDs)," individuals because otherwise categorical proportions of ",settings$covStrat," cannot be kept.\n"))
            warningAlreadyDisplayed = TRUE
          }
          
        }
        # get the datas
        data <- NULL
        dataID <- NULL
        indexLineFull <- NULL
        
        for(indexSampleSize in 1:length(sampleIDs)){
          indexLine <- which(dataset[,indexID]==sampleIDs[indexSampleSize])
          indexLineFull <- c(indexLineFull,indexLine)
          dataID <- c(dataID, rep(indexSampleSize,length(indexLine)))
        }
        data <- dataset[indexLineFull,]
        data[,indexID] <- dataID
        write.table(x = data, file = datasetFileName, sep = sepBoot,
                    eol = '\n', quote = FALSE, dec = '.',  row.names = FALSE, col.names = TRUE )
      }
      ##################################################################################################################
      # Generate the project file
      ##################################################################################################################
      # set the data file and the export directory
      bootData <- referenceDataset
      bootData$dataFile <- datasetFileName
      setData(bootData)
      saveProject(projectFile = paste0(exportDir,'/bootstrap/',projectName,'_bootstrap_',toString(indexSample),'.mlxtran'))
    }
  }else{
    cat("Reading data sets from the dataFolder...\n")
    dataFiles <- list.files(path = dataFolder, pattern = '*.txt|*.csv')
    cat("Generating projects with bootstrap data sets...\n")
    for(indexSample in 1:length(dataFiles)){
      bootData <- referenceDataset
      bootData$dataFile <- paste0(dataFolder,dataFiles[indexSample])
      setData(bootData)
      saveProject(projectFile = paste0(exportDir,'/bootstrap/',projectName,'_bootstrap_',toString(indexSample),'.mlxtran'))
    }
  }
  
}

##################################################################################################################
# Clean the bootstrap folder
##################################################################################################################
cleanbootstrap <- function(project){
  # Prepare all the output folders
  cat('Clearing all previous results and projects')
  loadProject(project)
  exportDir <- getProjectSettings()$directory
  listProjectsToDelete <- list.files(path = paste0(exportDir,'/bootstrap/'), pattern = '*.mlxtran')
  
  if(length(listProjectsToDelete)>0){
    for(indexProject in 1:length(listProjectsToDelete)){
      projectBoot <-  paste0(exportDir,'/bootstrap/',listProjectsToDelete[indexProject])
      exportDirToClean <- gsub(x = projectBoot, pattern = '.mlxtran', '')
      unlink(exportDirToClean, recursive = TRUE)
      unlink(projectBoot, recursive = FALSE)
    }
  }
  unlink(file.path(exportDir, '/bootstrap/data/'), recursive = TRUE, force = TRUE)
}

###################################################################################
# Check the inputs
###################################################################################
.checkBootstrapInput = function(inputName, inputValue){
  isValid = TRUE
  inputName = tolower(inputName)
  if(inputName == tolower("settings")){
    if(is.list(inputValue) == FALSE){
      message("ERROR: Unexpected type encountered. settings must be a list")
      isValid = FALSE
    }else {
      for (i in 1:length(inputValue)){
        if(!.checkBootstrapSettings(settingName = names(inputValue)[i], settingValue = inputValue[[i]])){
          isValid = FALSE
        }
      }
    }
  }else if(inputName == tolower("nboot")){
    if(!is.double(inputValue)){
      message("ERROR: Unexpected type encountered. nboot must be an integer")
      isValid = FALSE
    }else if (!(floor(inputValue)==inputValue)){
      message("ERROR: Unexpected type encountered. nboot must be an integer")
      isValid = FALSE
    }
    
  }
  return(invisible(isValid))
}

.checkBootstrapSettings = function(settingName, settingValue){
  isValid = TRUE
  settingName = tolower(settingName)
  if(settingName == tolower("N")){
    if((is.double(settingValue) == FALSE)&&(is.integer(settingValue) == FALSE)){
      message("ERROR: Unexpected type encountered. N must be an integer.")
      isValid = FALSE
    }else{
      if(!(as.integer(settingValue) == settingValue)){
        message("ERROR: Unexpected type encountered. N must be an integer.")
        isValid = FALSE
      }else if(settingValue<1){
        message("ERROR: N must be a strictly positive integer.")
        isValid = FALSE
      }
    }
  }else if(settingName == tolower("nboot")){
    if((is.double(settingValue) == FALSE)&&(is.integer(settingValue) == FALSE)){
      message("ERROR: Unexpected type encountered. nboot must be an integer.")
      isValid = FALSE
    }else{
      if(!(as.integer(settingValue) == settingValue)){
        message("ERROR: Unexpected type encountered. nboot must be an integer.")
        isValid = FALSE
      }else if(settingValue<1){
        message("ERROR: nboot must be a strictly positive integer.")
        isValid = FALSE
      }
    }
  }else if(settingName == tolower("level")){
    if((is.double(settingValue) == FALSE)){
      message("ERROR: Unexpected type encountered. level must be an double")
      isValid = FALSE
    }else{
      if(settingValue <= 0){
        message("ERROR: Unexpected type encountered. level must be strictly positive")
        isValid = FALSE
      }else if(settingValue>=1){
        message("ERROR: level must be strictly lower than 1.")
        isValid = FALSE
      }
    }
  }else if(settingName == tolower("newResampling")){
    if((is.logical(settingValue) == FALSE)){
      message("ERROR: Unexpected type encountered. newResampling must be an boolean")
      isValid = FALSE
    }
  }else if(settingName == tolower("plot")){
    if((is.logical(settingValue) == FALSE)){
      message("ERROR: Unexpected type encountered. plot must be an boolean")
      isValid = FALSE
    }
  }else if(settingName == tolower("covStrat")){
    if(is.character(settingValue) == FALSE){
      message("ERROR: Unexpected type encountered. covStrat must be a string")
      isValid = FALSE
    }else if(length(settingValue) >1){
      message("ERROR: Unexpected length. covStrat must be a single string (not a vector, nor a list)")
      isValid = FALSE
    }else{
      if(length(intersect(getCovariateInformation()$name, settingValue))==0){
        message(paste0("ERROR: ",settingValue," is not a valid covariate of the project."))
        isValid = FALSE
      }else{
        indexCAT <- which(getCovariateInformation()$name==settingValue)
        catType <- getCovariateInformation()$type[indexCAT[1]]
        if(!((catType=="categorical")||(catType=="categoricaltransformed"))){
          message(paste0("ERROR: ",settingValue," is not a categorical covariate."))
          isValid = FALSE
        }
      }
    }
  }else{
    message("ERROR: ",settingName,' is not a valid setting.')
    isValid = FALSE
  }
  return(isValid)
}