#' Estimate alpha-Relative Density Ratio p(x)/(alpha p(x) + (1-alpha) q(x))
#' by RuLSIF (Relative unconstrained Least-Square Importance Fitting)
#'
#' @param x1 numeric vector or matrix. Data from a numerator distribution p(x).
#' @param x2 numeric vector or matrix. Data from a denominator distribution q(x).
#' @param sigma positive numeric vector. Search range of Gaussian kernel bandwidth.
#' @param lambda positive numeric vector. Search range of regularization parameter.
#' @param alpha numeric value from 0.0 to 1.0. Relative parameter. Default 0.1.
#' @param kernel_num positive integer. Number of kernels.
#' @param verbose logical. Default TRUE.
#'
#' @return RuLSIF object which has `compute_density_ratio()`.
#'
#' @export
RuLSIF <- function(x1, x2,
                  sigma = 10 ^ seq(-3, 1, length.out = 9),
                  lambda = 10 ^ seq(-3, 1, length.out = 9),
                  alpha = 0.1, kernel_num = 100, verbose = TRUE) {

  if (verbose) message("################## Start RuLSIF ##################")
  if (is.vector(x1)) x1 <- matrix(x1)
  if (is.vector(x2)) x2 <- matrix(x2)
  if (ncol(x1) != ncol(x2)) stop("x1 and x2 must be same dimensions.")

  nx1 <- nrow(x1)
  nx2 <- nrow(x2)

  kernel_num <- min(kernel_num, nx1)
  centers <- x1[sample(nx1, size = kernel_num), , drop = FALSE]

  if(length(sigma) != 1 || length(lambda) != 1) {
    if(verbose) message("Searching optimal sigma and lambda...")
    opt_params <- RuLSIF_search_sigma_and_lambda(x1, x2, centers, sigma, lambda, alpha, verbose)
    sigma <- opt_params$sigma
    lambda <- opt_params$lambda
    if(verbose) message(sprintf("Found optimal sigma = %.3f, lambda = %.3f.", sigma, lambda))
  }

  if(verbose) message("Optimizing kernel weights...")
  phi_x1 <- compute_kernel_Gaussian(x1, centers, sigma)
  phi_x2 <- compute_kernel_Gaussian(x2, centers, sigma)
  H <- alpha * crossprod(phi_x1) / nx1 + (1 - alpha) * crossprod(phi_x2) / nx2
  h <- colMeans(phi_x1)
  kernel_weights <- solve(H + diag(lambda, kernel_num, kernel_num)) %*% h
  kernel_weights[kernel_weights < 0] <- 0
  if(verbose) message("End.")

  result <- list(kernel_weights = as.vector(kernel_weights),
                 lambda = lambda,
                 alpha = alpha,
                 kernel_info = list(
                   kernel = "Gaussian",
                   kernel_num = kernel_num,
                   sigma = sigma,
                   centers = centers
                 ),
                 compute_density_ratio = function(x) {
                   if(is.vector(x)) x <- matrix(x)
                   phi_x <- compute_kernel_Gaussian(x, centers, sigma)
                   density_ratio <- as.vector(phi_x %*% kernel_weights)
                   density_ratio
                 }
  )
  class(result) <- c("RuLSIF", class(result))
  if(verbose) message("################## Finished RuLSIF ###############")
  result
}
