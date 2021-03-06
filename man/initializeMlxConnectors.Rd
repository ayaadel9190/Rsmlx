% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/APIManager.R
\name{initializeMlxConnectors}
\alias{initializeMlxConnectors}
\title{Initialize MlxConnectors API}
\usage{
initializeMlxConnectors(software, mlxDirectory = "")
}
\arguments{
\item{software}{(\emph{character}) Name of the software to be loaded : "monolix"\cr}

\item{mlxDirectory}{(\emph{character}) [optional] Path to installation directory of the Lixoft suite.
If no path is given, the one written in the lixoft.ini file is used.}
}
\value{
A boolean equaling TRUE if the initialization has been successful and FALSE if not.
}
\description{
Initialize MlxConnectors API for a given software
}
\examples{
\dontrun{
initializeMlxConnectors(software = "monolix", mlxDirectory = "/path/to/mlxRuntime/")
}
}
