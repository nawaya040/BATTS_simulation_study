KLIEP_search_sigma_list <- function(x, y, centers, sigma_list, fold, verbose = TRUE) {
  sigma <- NULL
  score <- -Inf

  for(sigma_new in sigma_list) {
    score_new <- KLIEP_compute_score_cv(sigma_new, x, y, centers, fold)
    if (score_new > score) {
      score <- score_new
      sigma <- sigma_new
      if(verbose) message(sprintf("  sigma = %.5f, score = %f", sigma, score))
    }
  }
  sigma
}
