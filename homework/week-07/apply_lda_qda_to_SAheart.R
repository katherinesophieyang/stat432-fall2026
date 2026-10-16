# Apply the explicitly invoked lda-qda-analysis-report skill to SAheart.
# Reproducible analysis: seed 43217; stratified 70/30 train/test split;
# 5-fold stratified CV on training data; same folds for every candidate.
# Predictors follow STAT 432 Question 1 coding: famhist Absent=1, Present=2.

set.seed(43217)
seed_used <- 43217
library(MASS)

heart <- read.csv(file.path("data", "saheart.csv"), stringsAsFactors = FALSE)
heart$famhist <- ifelse(heart$famhist == "Absent", 1,
                        ifelse(heart$famhist == "Present", 2, NA_real_))
heart$chd <- factor(heart$chd, levels = c(0, 1))

predictor_names <- setdiff(names(heart), "chd")
if (anyNA(heart[, c("chd", predictor_names)])) {
  stop("Missing values found. Specify a missing-data strategy before proceeding.")
}
X <- as.matrix(heart[, predictor_names])
storage.mode(X) <- "double"
y <- heart$chd
n <- nrow(heart)

# Stratified 70/30 holdout; reserve test rows before model selection.
train_idx <- unlist(lapply(levels(y), function(cl) {
  ids <- which(y == cl)
  sample(ids, size = floor(0.70 * length(ids)))
}), use.names = FALSE)
train_idx <- sort(train_idx)
test_idx <- setdiff(seq_len(n), train_idx)

X_train <- X[train_idx, , drop = FALSE]
y_train <- droplevels(y[train_idx])
X_test <- X[test_idx, , drop = FALSE]
y_test <- y[test_idx]

# Create 5 stratified folds once. Every candidate uses these exact folds.
K <- 5
fold_id <- integer(length(train_idx))
for (cl in levels(y_train)) {
  local_ids <- which(y_train == cl)
  fold_id[local_ids] <- sample(rep(seq_len(K), length.out = length(local_ids)))
}

# Candidate models: ordinary LDA, ordinary QDA, and blends of posterior
# probabilities. blend_qda is the weight assigned to QDA (0=LDA, 1=QDA).
# Candidate models: ordinary LDA, ordinary QDA, and probability blends.
# LDA/QDA are listed separately; blend endpoints are not duplicated.

fit_posteriors <- function(method, x_train, y_train, x_new) {
  if (method == "LDA") {
    fit <- MASS::lda(x = x_train, grouping = y_train)
    return(predict(fit, x_new)$posterior[, levels(y_train), drop = FALSE])
  }
  if (method == "QDA") {
    fit <- MASS::qda(x = x_train, grouping = y_train)
    return(predict(fit, x_new)$posterior[, levels(y_train), drop = FALSE])
  }
  stop("Unknown method")
}

# Candidate list avoids duplicate pure-model endpoints.
candidate_names <- c("LDA", "QDA", "Blend (QDA weight 0.25)",
                     "Blend (QDA weight 0.50)", "Blend (QDA weight 0.75)")
blend_weights <- c(NA_real_, NA_real_, 0.25, 0.50, 0.75)

# Out-of-fold class-1 probabilities for each candidate.
oof_prob <- matrix(NA_real_, nrow = length(train_idx),
                   ncol = length(candidate_names),
                   dimnames = list(NULL, candidate_names))
candidate_status <- setNames(rep("OK", length(candidate_names)), candidate_names)

for (fold in seq_len(K)) {
  analysis_ids <- which(fold_id != fold)
  validation_ids <- which(fold_id == fold)
  x_a <- X_train[analysis_ids, , drop = FALSE]
  y_a <- droplevels(y_train[analysis_ids])
  x_v <- X_train[validation_ids, , drop = FALSE]

  # Fit both base models once per fold; all blends reuse these probabilities.
  lda_p <- tryCatch(fit_posteriors("LDA", x_a, y_a, x_v),
                    error = function(e) e)
  qda_p <- tryCatch(fit_posteriors("QDA", x_a, y_a, x_v),
                    error = function(e) e)

  if (inherits(lda_p, "error")) {
    candidate_status["LDA"] <- paste("Failed:", conditionMessage(lda_p))
  } else {
    oof_prob[validation_ids, "LDA"] <- lda_p[, "1"]
  }

  if (inherits(qda_p, "error")) {
    candidate_status["QDA"] <- paste("Failed:", conditionMessage(qda_p))
    candidate_status[grepl("Blend", names(candidate_status))] <-
      paste("Unavailable because QDA failed:", conditionMessage(qda_p))
  } else {
    oof_prob[validation_ids, "QDA"] <- qda_p[, "1"]
  }

  if (!inherits(lda_p, "error") && !inherits(qda_p, "error")) {
    for (j in 3:5) {
      w <- blend_weights[j]
      oof_prob[validation_ids, j] <-
        (1 - w) * lda_p[, "1"] + w * qda_p[, "1"]
    }
  }
}

# CV misclassification rate at the 0.5 posterior threshold.
cv_error <- rep(NA_real_, length(candidate_names))
names(cv_error) <- candidate_names
for (j in seq_along(candidate_names)) {
  if (all(is.finite(oof_prob[, j]))) {
    pred <- factor(ifelse(oof_prob[, j] >= 0.5, "1", "0"),
                   levels = levels(y_train))
    cv_error[j] <- mean(pred != y_train)
  } else if (candidate_status[j] == "OK") {
    candidate_status[j] <- "Failed: incomplete out-of-fold predictions"
  }
}
if (all(is.na(cv_error))) stop("All candidate models failed during cross-validation.")

cv_table <- data.frame(
  Candidate = candidate_names,
  CV_Misclassification = as.numeric(cv_error),
  Status = unname(candidate_status),
  stringsAsFactors = FALSE
)
eligible <- which(is.finite(cv_error))
selected_idx <- eligible[which.min(cv_error[eligible])]
selected_name <- candidate_names[selected_idx]
selected_weight <- blend_weights[selected_idx]

# Refit selected pipeline on all training observations, then evaluate test once.
if (selected_name == "LDA") {
  lda_full <- MASS::lda(X_train, y_train)
  test_prob <- predict(lda_full, X_test)$posterior[, "1"]
  selected_description <- "Ordinary LDA"
} else if (selected_name == "QDA") {
  qda_full <- MASS::qda(X_train, y_train)
  test_prob <- predict(qda_full, X_test)$posterior[, "1"]
  selected_description <- "Ordinary QDA"
} else {
  lda_full <- MASS::lda(X_train, y_train)
  qda_full <- MASS::qda(X_train, y_train)
  p_lda <- predict(lda_full, X_test)$posterior[, "1"]
  p_qda <- predict(qda_full, X_test)$posterior[, "1"]
  test_prob <- (1 - selected_weight) * p_lda + selected_weight * p_qda
  selected_description <- paste0("LDA/QDA posterior blend; QDA weight = ",
                                 selected_weight)
}
test_pred <- factor(ifelse(test_prob >= 0.5, "1", "0"), levels = levels(y_test))
test_error <- mean(test_pred != y_test)
test_cm <- table(Observed = y_test, Predicted = test_pred)

cv_table$Selected <- cv_table$Candidate == selected_name
print(paste("Random seed:", seed_used))
print(paste("Rows:", n, "| training:", length(train_idx),
            "| test:", length(test_idx)))
print("Cross-validation results:")
print(cv_table, row.names = FALSE)
print(paste("Selected model:", selected_name))
print(paste("Test misclassification rate:", round(test_error, 4)))
print("Test confusion matrix (observed rows, predicted columns):")
print(test_cm)

# Save the one-page report as a PDF. A single page contains a figure, table,
# test confusion matrix, numerical results, and concise interpretation.
pdf("SAheart_LDA_QDA_report.pdf", width = 11, height = 8.5, onefile = TRUE)
layout(matrix(c(1, 2, 3, 3), nrow = 2, byrow = TRUE),
       widths = c(1.65, 1), heights = c(1, 0.95))
par(oma = c(0.3, 0.3, 2.4, 0.3), mar = c(4.2, 4.2, 2.8, 1))

# Panel 1: cross-validation error figure
valid <- is.finite(cv_error)
short_names <- c("LDA", "QDA", "Blend\n0.25", "Blend\n0.50", "Blend\n0.75")
plot(which(valid), cv_error[valid], type = "b", pch = 19, lwd = 2,
     xaxt = "n", xlab = "", ylab = "5-fold CV misclassification rate",
     main = "Training-only model selection",
     ylim = range(c(0.25, cv_error[valid], 0.32)))
axis(1, at = which(valid), labels = short_names[valid], cex.axis = 0.9)
abline(h = cv_error[selected_idx], lty = 2, col = "gray40")
mtext("Lower is better", side = 1, line = 3.2, cex = 0.85)
mtext("SAheart: LDA, QDA, and probability blends",
      side = 3, outer = TRUE, line = 0.7, cex = 1.25, font = 2)

# Panel 2: compact CV table
par(mar = c(1, 1, 2.8, 1))
plot.new()
title("Cross-validation results", line = 1)
text(c(0.02, 0.79, 0.98), 0.84,
     labels = c("Candidate", "CV error", "Chosen"),
     adj = c(0, 0.5, 1), font = 2, cex = 0.82)
candidate_labels <- c("LDA", "QDA", "LDA/QDA (0.25)",
                      "LDA/QDA (0.50)", "LDA/QDA (0.75)")
row_y <- seq(0.72, 0.32, length.out = length(candidate_labels))
for (i in seq_along(candidate_labels)) {
  text(0.02, row_y[i], candidate_labels[i], adj = c(0, 0.5), cex = 0.82)
  text(0.79, row_y[i], sprintf("%.4f", cv_error[i]),
       adj = c(0, 0.5), cex = 0.82)
  text(0.98, row_y[i], if (cv_table$Selected[i]) "Yes" else "",
       adj = c(1, 0.5), cex = 0.82, font = 2)
}
text(0.02, 0.2, "Blend values are QDA posterior weights.",
     adj = c(0, 0.5), cex = 0.8)

# Panel 3: test results, confusion matrix, interpretation and limitations
par(mar = c(0.4, 0.5, 1.8, 0.5))
plot.new()
title("Selected model and held-out test evaluation", line = 0.5)
narrative <- c(
  sprintf("SAheart (n=%d); response chd; predictors: sbp, tobacco, ldl, adiposity, famhist,", n),
  "typea, obesity, alcohol, age. famhist: Absent=1, Present=2.",
  sprintf("Stratified split: %d train / %d test (70/30); random seed %d.",
          length(train_idx), length(test_idx), seed_used),
  "Selection: same stratified 5 folds; 0.5 cutoff; lowest error; blend weight is QDA's.",
  sprintf("CV tie: LDA and 0.25-QDA blend (%.4f); LDA selected (first in candidate order).",
          cv_error[selected_idx]),
  sprintf("Refit: %s on all training data; test evaluated once: %.4f (%.2f%%).",
          selected_description, test_error, 100 * test_error),
  "LDA assumes a shared class covariance; QDA estimates separate covariances. QDA's",
  "greater flexibility can reduce bias but increase estimation variance; blending combines",
  "their probabilities. Limits: modest sample, split variability, and no external validation;",
  "predictive results do not establish causality or clinical validity."
)
text(0.02, 0.91, paste(narrative, collapse = "\n"),
     adj = c(0, 1), cex = 0.88)
text(0.73, 0.89, "Confusion matrix (predicted columns)",
     adj = c(0, 1), font = 2, cex = 0.95)
cm_lines <- c(
  sprintf("%-15s %7s %7s", "Observed", "chd=0", "chd=1"),
  sprintf("%-15s %7d %7d", "chd=0", test_cm["0", "0"], test_cm["0", "1"]),
  sprintf("%-15s %7d %7d", "chd=1", test_cm["1", "0"], test_cm["1", "1"])
)
text(0.73, 0.79, paste(cm_lines, collapse = "\n"),
     adj = c(0, 1), family = "mono", cex = 0.85)
dev.off()

# Also save a plain-text report for convenient editing/submission.
report_lines <- c(
  "SAheart LDA/QDA analysis",
  sprintf("Seed: %d; n=%d; training=%d; test=%d.", seed_used, n, length(train_idx), length(test_idx)),
  "Predictors: all nine variables other than chd; famhist Absent=1, Present=2.",
  "Split: stratified 70/30. Selection: stratified 5-fold CV on training data; same folds for all candidates.",
  "",
  "Cross-validation results:",
  capture.output(print(cv_table, row.names = FALSE)),
  "",
  sprintf("Selected model: %s", selected_description),
  sprintf("Held-out test misclassification rate: %.4f (%.2f%%)", test_error, 100 * test_error),
  "Test confusion matrix (observed rows, predicted columns):",
  capture.output(print(test_cm)),
  "",
  "Interpretation: LDA assumes a shared covariance matrix; QDA estimates separate class covariance matrices.",
  "A posterior blend can trade model bias against estimation variance. Results may vary with the split,",
  "and a single held-out test set is not external validation."
)
writeLines(report_lines, "SAheart_LDA_QDA_report.txt")
