KLIEP_compute_score_cv <- function(sigma, x, y, centers, fold) {
  phi_x <- compute_kernel_Gaussian(x, centers, sigma)
  phi_y <- compute_kernel_Gaussian(y, centers, sigma)
  mean_phi_y <- matrix(colMeans(phi_y))

  nx <- nrow(x)
  cv_split <- sample(nx) %% fold + 1

  scores <- numeric(fold)
  for (i in seq_len(fold)) {
    alpha <- KLIEP_optimize_alpha(phi_x[cv_split != i, ], mean_phi_y = mean_phi_y)
    scores[i] <- KLIEP_compute_score(phi_x[cv_split == i, ], alpha)
  }
  score_new <- mean(scores)
  score_new
}

KLIEP_compute_score <- function(phi, alpha) {
  mean(log(phi %*% alpha))
}

