compute_kernel_Gaussian <- function(x, centers, sigma) {
  apply(centers, 1, function(center) {
    apply(x, 1, function(row) {
      kernel_Gaussian(row, center, sigma)
    })
  })
}

kernel_Gaussian <- function(x, y, sigma) {
  exp(- squared_euclid_distance(x, y) / (2 * sigma * sigma))
}

#' Compute Squared Euclid Distance
#'
#' @param x a numeric vector.
#' @param y a numeric vector.
#'
#' @return squared Euclid distance
squared_euclid_distance <- function(x, y) {
  sum((x - y) ^ 2)
}
