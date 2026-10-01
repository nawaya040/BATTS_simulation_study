#' Estimate Density Ratio p(x)/q(x)
#'
#' @param x1 numeric vector or matrix. Data from a numerator distribution p(x).
#' @param x2 numeric vector or matrix. Data from a denominator distribution q(x).
#' @param method "uLSIF" (default), "RuLSIF", or "KLIEP".
#' @param sigma positive numeric vector. Search range of Gaussian kernel bandwidth.
#' @param lambda positive numeric vector. Search range of regularization parameter for uLSIF and RuLSIF.
#' @param alpha numeric in [0, 1]. Relative parameter for RuLSIF. Default 0.1.
#' @param kernel_num positive integer. Number of kernels.
#' @param fold positive integer. Numer of the folds of cross validation for KLIEP.
#' @param verbose logical (default TRUE).
#'
#' @return densratio object that contains a function to compute estimated density ratio.
#'
#' @examples
#' x1 <- rnorm(200, mean = 1, sd = 1/8)
#' x2 <- rnorm(200, mean = 1, sd = 1/2)
#'
#' densratio_obj <- densratio(x1, x2)
#'
#' new_x <- seq(0, 2, by = 0.05)
#' estimated_density_ratio <- densratio_obj$compute_density_ratio(new_x)
#'
#' plot(new_x, estimated_density_ratio, pch=19)
#'
#' @export
densratio <- function(x1, x2, method = c("uLSIF", "RuLSIF", "KLIEP"),
                      sigma = "auto", lambda = "auto", alpha = 0.1,
                      kernel_num = 100, fold = 5, verbose = TRUE) {
  # Prepare Arguments -------------------------------------------------------
  method <- match.arg(method)

  # To Retain Default Arguments in Functions of Methods ---------------------
  params <- alist(x1 = x1, x2 = x2, kernel_num = kernel_num, verbose = verbose)
  if (!identical(sigma, "auto")) {
    params <- c(params, alist(sigma = sigma))
  }

  # Run ---------------------------------------------------------------------
  if (method == "uLSIF") {
    if (!identical(lambda, "auto")) params <- c(params, alist(lambda = lambda))
    result <- do.call(uLSIF, params)
  } else if (method == "RuLSIF") {
    if (!identical(lambda, "auto")) params <- c(params, alist(lambda = lambda))
    params <- c(params, alist(alpha = alpha))
    result <- do.call(RuLSIF, params)
  } else {
    params <- c(params, alist(fold = fold))
    result <- do.call(KLIEP, params)
  }

  # Result ------------------------------------------------------------------
  cl <- match.call()
  cl[["method"]] <- method
  result$call <- cl

  class(result) <- c("densratio", class(result))
  result
}
