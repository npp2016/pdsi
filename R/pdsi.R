## TODO how to remove tempdirs on Windows?
## TODO add Linux support

##' Calculates monthly scPDSI series from temperature and
##' precipitation data. Uses binaries compiled from official
##' University of Nebraska C++ Code.
##'
##' This function transforms the input climate data into the necessary
##' files for the PDSI binary executable and saves them to a temp
##' directory. The binary is called and the resulting files of
##' interest for PDSI and scPDSI are read in again and returned.
##' 
##' For details on the algorithm, see the comments in the C++ source
##' file. For reference, the source code is put in the toplevel
##' installation directory of the package, you may find it using
##' \code{system.file(package = "pdsi")}.
##'
##' Note: this package works only with Windows and Mac OS X so far.
##' @title Calculation of (sc)PDSI
##' @param awc Available soil water capacity (in cm)
##' @param lat Latitude of the site (in decimal degrees)
##' @param climate {\code{data.frame} with monthly climate data
##' consisting of 4 columns for year, month, temperature (deg C), and
##' precipitation (mm)
##' @param start Start year for PDSI calculation
##' @param end End year for PDSI calculation
##' @return A \code{list} of two \code{data.frames}, one holding the
##' standard PDSI, one holding the scPDSI.
##' @references Methodology based on Research Paper No. 45;
##' Meteorological Drought; by Wayne C. Palmer for the U.S. Weather
##' Bureau, February 1965.
##' @keywords utils
##' @examples
##' library(bootRes)
##' data(muc.clim)
##' pdsi(12, 50, muc.clim, 1960, 2000)
##' @importFrom bootRes pmat
##' @export
pdsi <- function(awc, lat, climate, start, end) {

  ## check the system we are on
  the_system <- Sys.info()["sysname"]

  ## create temp dir
  require(digest)
  tempdir <- paste(getwd(), "/", digest(Sys.time()), sep = "")
  dir.create(tempdir)

  require(bootRes)                      # TODO put this into @imports

  ## convert to fahrenheit and inch
  climate[,3] <- round(climate[,3]*1.8 + 32, 3)
  climate[,4] <- round(climate[,4]/25.4, 3)
  
  ## truncate and reformat climate data
  climate_start <- which(climate[,1] == start-1)[1]
  climate_end <- which(climate[,1] == end)[12]
  climate <- climate[climate_start:climate_end,]
  climate_reform <- pmat(climate, start = 1, end = 12)
  
  ## split in temp and prec
  pmat_temp <- climate_reform[,1:12]
  pmat_prec <- climate_reform[,13:24]
  
  ## write to files
  temp_path <- file.path(tempdir, "monthly_T")
  prec_path <- file.path(tempdir, "monthly_P")
  write.table(pmat_temp, temp_path, col.names = F, quote = F)
  write.table(pmat_prec, prec_path, col.names = F, quote = F)
  
  ## calculate mean values and write to files
  normal_temp <- round(t(as.vector(colMeans(pmat_temp))), 3)
  normal_prec <- round(t(as.vector(colMeans(pmat_prec))), 3)
  normal_temp_path <- file.path(tempdir, "mon_T_normal")
  normal_prec_path <- file.path(tempdir, "mon_P_normal")
  write.table(normal_temp, normal_temp_path, col.names = F, quote = F,
              row.names = F)
  write.table(normal_prec, normal_prec_path, col.names = F, quote = F,
              row.names = F)
  
  ## write parameter files to tempdir
  params <- t(c(awc, lat))
  param_path <- file.path(tempdir, "parameter")
  write.table(params, param_path, col.names = F, quote = F,
              row.names = F)

  ## run executable (depending on platform)
  if (the_system == "Windows") {
    exec_path <- file.path(system.file(package = "pdsi"), "exec", "sc-pdsi.exe")
  } else {
    exec_path <- file.path(system.file(package = "pdsi"), "exec", "pdsi")
  }

  oldwd <- getwd()
  setwd(tempdir)
  
  cmd <- paste(exec_path, "-i", shQuote(tempdir), start, end)
  system(cmd)

  setwd(oldwd)

  ## read (sc)PDSI in again and return it
  scpdsi_path <- file.path(tempdir, "monthly", "self_cal", "PDSI.tbl")
  pdsi_path <- file.path(tempdir, "monthly", "original", "PDSI.tbl")
  scPDSI <- read.table(scpdsi_path)
  PDSI <- read.table(pdsi_path)
  file.remove(tempdir, recursive = TRUE)
  system(delcmd)
  colnames(PDSI) <- c("YEAR", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL",
                      "AUG", "SEP", "OCT", "NOV", "DEC")
  colnames(scPDSI) <- c("YEAR", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL",
                      "AUG", "SEP", "OCT", "NOV", "DEC")
  list(PDSI, scPDSI)
}