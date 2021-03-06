% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcssUpdate.R
\name{RcssChange}
\alias{RcssChange}
\title{Modify an Rcss style sheet object}
\usage{
RcssChange(
  selector,
  propertylist = NULL,
  property = NULL,
  value = NULL,
  Rcssclass = NULL,
  Rcss = "default"
)
}
\arguments{
\item{selector}{name of one selector ("text", "plot", "axis", etc.)}

\item{propertylist}{list with property/value pairs to update}

\item{property}{name of a single property. This is only used
when propertylist is set to NULL}

\item{value}{new values associated with property above. This is
only used propertylist is set to NULL}

\item{Rcssclass}{subclass of style sheet. Leave NULL to change
base property. Provide one character value to edit one subclass.
Provide a vector to edit a subclass of a subclass of a ...}

\item{Rcss}{style sheet object}
}
\value{
always returns an Rcss object. Note: when changing
the default style, this will return a new style without
actually affecting the default style. To change how the
default works in practice, assign this return value to
RcssDefaultStyle
}
\description{
Creates a new Rcss style sheet object from the input, modifying
one or more properties.
}
\examples{

style1 <- Rcss(text="points { cex: 1; pch: 19; }")
printRcss("points", Rcss=style1, verbose=TRUE)
style2 <- RcssChange("points", list(cex=2), Rcss=style1)
printRcss("points", Rcss=style2, verbose=TRUE)

}
