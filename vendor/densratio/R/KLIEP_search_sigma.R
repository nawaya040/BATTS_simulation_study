KLIEP_search_sigma <- function(x, y, centers, fold, verbose = TRUE) {
  sigma <- 10
  score <- -Inf

  for (digit_position in 0:-5) {
    for (i in 1:9) {
      sigma_new <- sigma - 10 ^ digit_position

      score_new <- KLIEP_compute_score_cv(sigma_new, x, y, centers, fold)
      if (score_new <= score) {
        break
      }
      score <- score_new
      sigma <- sigma_new
      if(verbose) message(sprintf("  sigma = %.5f, score = %f", sigma, score))
    }
  }
  sigma
}
