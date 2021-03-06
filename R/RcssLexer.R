# Functions part of Rcssplot package
#
# Lexer for Rcssplot.
# Use RcssLexer to read a file from disk and split into tokens
#  
#
# Author: Tomasz Konopka
#
#
# The Lexer implements grammar (for guidance only)
# The lexer is implemented by hand, and the grammar written afterward)
#
#
# Input: Token MoreTokens
# Token: Terminals | Comment | Number | String
# MoreTokens: EMPTY | Token MoreTokens
# Terminals: one of ".:;{}="
#


#' start the Lexer
#'
#' @keywords internal
#' @noRd
#' @param f character, input file, or vector of input files
#' @param text character, strings with Rcss
#'
#' @return data frame with tokens
RcssLexer <- function(file=NULL, text=NULL) {
  # obtain content from all input objects
  fdata <- c()
  if (!is.null(file)) {
    fdata <- lapply(as.list(file), RcssFileCheckRead)
    fdata <- unlist(fdata)
  }
  if (!is.null(text)) {
    fdata <- c(fdata, unlist(strsplit(text, "\n")))
  }
  # split contnt into character, record line numbers
  flines <- seq_len(length(fdata))
  flen <- sapply(fdata, nchar)
  fdata <- unlist(strsplit(fdata, ""))
  fdata <- data.frame(char=fdata, line=rep(flines, flen),
                      stringsAsFactors=FALSE)
  # process the characters
  RcssLexChars(fdata)
}


#' check if a file exists, then read it
#'
#' @keywords internal
#' @noRd
#' @param f character, single file name
#'
#' @return contents of file with a space and a newline character
#' added at end of each line (these characters are convenient for lexing)
RcssFileCheckRead <- function(f) {
  if (!file.exists(f)) {
    stopCF("RcssFileCheckRead: input file does not exist: ", f, "\n");
  }
  fcon <- file(f, open="r")
  fdata <- readLines(fcon)
  close(fcon)
  paste(fdata, "\n")
}


# ################################################################
# Organization of the Lexer


#' The root of the actual lexer.
#' Technically, this keeps track of the lexed tokens.
#' Dispatches to other tokens to parse the next tokens.
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos integer, current position in the character vector
#'
#' @return data frame with pairs (token, tokentype)
RcssLexChars <- function(chardata, pos=1) {
  
  # bookkeeping
  cclen <- nrow(chardata)
  line.numbers = chardata$line
  ans <- list()
  nowpos <- pos  
  numtokens <- 0
  
  # loop to fill list of tokens
  while(nowpos <= cclen) {
    # obtain information about next token
    thistoken <- RcssLexNextToken(chardata, nowpos)
    # record token, but not if it is a space
    if (!thistoken[3] %in% c("SPACE", "COMMENT")) {
      thispos = as.integer(thistoken[1])
      ans[[numtokens+1]] <- c(thistoken[2:3], line.numbers[thispos])
      numtokens <- numtokens + 1
    }
    # progress along
    nowpos <- as.integer(thistoken[1])
  }

  if (numtokens>0) {
    result <- data.frame(do.call(rbind, ans), stringsAsFactors = F)
    colnames(result) <- c("token", "type", "line")
  } else {
    result <- data.frame(token=NA, type=NA, line=NA)[c(),]
  }
  
  result
}


#' concatenate a subset of characters
#'
#' @keywords internal
#' @noRd
#' @param cc character vector
#' @param pos integer, start position
#' @param newpos integer, end position
#' @return a string containing characters in the interval
RcssGetToken <- function(cc, pos, newpos) {
  paste(cc[pos:(newpos - 1)], collapse = "")
}


#' process one token starting at position 'pos'
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos integer, current position in the cc vector
#' @param terminals character vector, characters that mark end of a token
#' @param spacechars character vector, all characters interpreted as a space
#'
#' @return triple (NEWPOSITION, TOKEN, TOKENTYPE)
RcssLexNextToken <- function(chardata, pos,
                             terminals=unlist(strsplit(".,;:{}=","")),
                             spacechars=unlist(strsplit(" \t\r\n\f",""))) {
  
  cc <- chardata$char
  nowchar <- cc[pos];
  
  if (nowchar %in% spacechars) {
    # space character - in this state skip
    return(c(pos + 1, nowchar, "SPACE"))    
  }

  if (nowchar %in% terminals) {
    return(c(pos + 1, nowchar, "TERMINAL"));  
  }

  if (nowchar == "/" & cc[pos + 1] == "*") {
    # This is the start of a comment
    newpos <- RcssParseComment(chardata, pos)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "COMMENT"))  
  }

  if (nowchar %in% c("\"", "\'")) {
    # start of a string
    newpos <- RcssParseString(chardata, pos, nowchar)
    token <- RcssGetToken(cc, pos, newpos)
    # strip the token of it's closing and opening delimiters
    token <- substr(token, 2, nchar(token)-1)
    return(c(newpos, token, "STRING"))  
  }
  
  if (nowchar == "#") {
    # start of a hex color string    
    newpos <- RcssParseHexToken(chardata, pos)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "HEXCOLOR"))  
  }

  if (nowchar %in% c("-", "+", seq(0,9))) {
    # start of a number
    newpos <- RcssParseNumber(chardata, pos)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "NUMBER"))
  }

  # something else - generic token
  newpos <- RcssParseGeneric(chardata, pos,
                             c(terminals, spacechars,
                               "\"", "'", "/", "#", "-", "+"))
  token <- RcssGetToken(cc, pos, newpos)
  c(newpos, token, "IDENT")
}


# ################################################################
# Functions that handle individual token types


#' parse a comment
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos current position (expects '/' followed by '*')
#'
#' @return position of first non-comment
RcssParseComment <- function(chardata, pos) {

  # cclen avoids reading beyond the vector length
  cc = chardata$char
  cclen <- length(cc)
  
  nowpos <- pos+2  
  while ((nowpos < cclen) & !(cc[nowpos] == "*" & cc[nowpos + 1] == "/")) {
    # not end of comment yet
    # check if perhaps nested comment
    if (cc[nowpos]=="/" & cc[nowpos + 1]=="*") {
      nowpos <- RcssParseComment(chardata, nowpos);
    } else {
      nowpos <- nowpos + 1
    }
  }
  
  # reached here, so either end of cc, or end of comment
  # for the return value, either case is fine
  nowpos + 2
}


#' helper for string parsing
#'
#' @keywords internal
#' @noRd
#' @param cc vector of characters
#' @param pos integer, position of character to check escape for (e.g. a " in a string)
#'
#' @return true if position  is preceded by an odd number of slashes
RcssIsEscaped <- function(cc, pos) {
  # prepos will be the start of a series of slashes prior to pos
  prepos <- pos
  while (prepos > 1 & cc[prepos - 1] == "\\") {
    prepos <- prepos - 1
  }  
  # count the number of slashes. Escaped if they are odd
  ((pos-prepos) %% 2 == 1)
}


#' parse a number
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos integer, current position (expects '-' or 0-9)
#' @param exponent logical, set TRUE if parsing an exponent of a number
#' @param decimal logical, set TRUE if parsing digits after a decimal point
#'
#' @return - position of first character outside the number
RcssParseNumber <- function(chardata, pos, exponent=FALSE, decimal=FALSE) {
  
  cc = chardata$char
  digits = seq(0, 9)  
  
  nowpos <- pos
  # avoid running over the length of the input
  if (nowpos>length(cc)) return(nowpos)
  
  # skip a minus sign or plus sign if there is one
  if (cc[pos] == "-" | cc[pos] == "+") {
    nowpos <- nowpos + 1
  }
  if (nowpos>length(cc)) return(nowpos)
  
  # a number must have at least one digit
  if (!(cc[nowpos] %in% digits)) {
    stopAtLine(paste0("RcssParseNumber expecting number, got ", cc[pos]),
               chardata$line[pos]);
  }
  
  # loop to skip over the digits
  while (nowpos<=length(cc) & cc[nowpos] %in% digits) {
    nowpos <- nowpos + 1
  }
  if (nowpos>length(cc)) return(nowpos)
  
  # after the first digits, can have a dot or an exponent
  if (cc[nowpos]==".") {
    # do not allow multiple dots
    if (decimal) {
      return(-nowpos)
    } else {
      nowpos <- RcssParseNumber(chardata, nowpos + 1,
                                exponent = exponent, decimal = TRUE)
    }
  } else if (cc[nowpos] %in% c("e", "E")) {
    # do not allow exponents in exponents
    if (exponent) {
      return(-nowpos)
    } else {
      nowpos <- RcssParseNumber(chardata, nowpos + 1,
                                exponent = TRUE, decimal = FALSE);
    }
  }
  
  # check for possible parse errors (return(-nowpos) above)
  if (nowpos<0) {
    msg = paste0("RcssParseNumber expecting number in format [-]X.XE[-]X\n",
                 "   ", paste(cc[pos:-nowpos], collapse = ""))
    stopAtLine(msg, chardata$line[-nowpos])
  }
  
  nowpos
}


#' parse a string
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos integer, current position (expects '/' followed by '*')
#' @param delimiter character, either " or ' (used to catch nested strings)
#'
#' @return - position of first character outside the string
RcssParseString <- function(chardata, pos, delimiter="\"") {
  
  cc <- chardata$char
  cclen <- length(cc)  
  nowpos <- pos + 1
  while ((nowpos < cclen) & cc[nowpos] != delimiter) {
    nowpos <- nowpos + 1
  }

  # at this stage, nowpos contains a string delimiter
  # But, if it is "escaped" with slashes, need to continue
  # By recursion, this will find the final (true) string delimiter
  if (RcssIsEscaped(cc, nowpos)) {
    nowpos <- RcssParseString(chardata, nowpos, delimiter = delimiter)
  }
  
  # at this stage, nowpos contains the final string delimiter
  # move the position to the next non-string character
  nowpos + 1
} 


#' parse a hex color
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos integer, current position (this function expects a hash sign)
#'
#' @return position of the next non-hex character
RcssParseHexToken <- function(chardata, pos) {
  
  # find all subsequent characters that are consistent with a color
  cc <- chardata$char
  nowpos <- pos + 1
  hexchars <- c(seq(0,9), letters[1:6], LETTERS[1:6])
  while ((cc[nowpos] %in% hexchars)) {
    nowpos <- nowpos + 1
  }
  
  # colors must have 6 or 8 characters
  hexlen <- nowpos - pos - 1
  if (hexlen != 6 & hexlen != 8) {
    msg = paste0("RcssParseHexToken:\n",
                 "expecting hex color in #RRGGBB or #RRGGBBAA format\n",
                 "   ",paste(cc[pos:(nowpos-1)], collapse = ""))
    stopAtLine(msg, chardata$line[nowpos])
  }
  
  # returns the position of the next non-hex character
  nowpos
}


#' parser for a generic token
#'
#' @keywords internal
#' @noRd
#' @param chardata data frame with characters and line numbers
#' @param pos integer current position
#' @param delimiters vector or delimiters that demarcate end of a token
#' (e.g. terminals not allowed in a variable name)
#'
#' @return position of first character beyond the current token
RcssParseGeneric <- function(chardata, pos, delimiters) {
  # loop through characters, accepting everything except delimiters
  cc <- chardata$char
  nowpos <- pos
  cclen <- length(cc)  
  while (nowpos <= cclen & !(cc[nowpos] %in% delimiters)) {
    nowpos <- nowpos + 1
  }
  nowpos
}

