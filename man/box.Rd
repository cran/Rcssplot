% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcssWrappers.R
\name{box}
\alias{box}
\title{Add a styled box around a plot}
\usage{
box(which = "plot", Rcss = "default", Rcssclass = NULL, ...)
}
\arguments{
\item{which}{character specifying where to draw a box;
see documentation of box()}

\item{Rcss}{style sheet object. Leave "default" to use a style
defined via RcssSetDefaultStyle()}

\item{Rcssclass}{sub class of style sheet}

\item{...}{Further parameters, see documentation of graphics::box}
}
\description{
This is a wrapper for R's box function.
See R's documentation for graphics::box for further details.
}
\examples{

# draw a box around an existing plot
plot(c(0, 1), c(0, 1), type="n", frame=FALSE)
box(lwd=3)

}
