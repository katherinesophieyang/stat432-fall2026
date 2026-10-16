---
name: lda-qda-analysis-report
description: Explicitly invoked workflow for evaluating LDA, QDA, and probability blends using leakage-safe validation and producing a concise one-page statistical report.
---

# Intent
Analyze a user-specified classification dataset using only LDA, QDA, or a probability combination of LDA and QDA. Produce a reproducible, concise statistical report. Do not assume any particular dataset, response, predictors, or observed results.

# Invocation
Use this skill only when the user explicitly asks to invoke or apply `lda-qda-analysis-report`. Do not load or apply it automatically. The user must provide the dataset, response variable, predictor variables, and any required predictor coding separately.

# Analysis instructions
1. Confirm the response classes, predictor types, missing values, and sample size. Apply only the coding and preprocessing specified by the user. State any additional handling and its rationale.
2. Set and report a random seed. Reserve a stratified test set before comparing models or selecting settings. Do not use test outcomes for model selection, preprocessing decisions, or revisions.
3. Compare ordinary LDA and ordinary QDA at minimum. Candidate extensions may include probability blends of LDA and QDA or PCA followed by LDA/QDA. Do not use classifiers outside LDA, QDA, or their combination.
4. Use the same stratified cross-validation folds for every candidate and setting. Select settings using training-only cross-validation misclassification rate. In each fold, estimate all preprocessing (including PCA, centering, scaling, or feature selection) using only that fold's analysis portion, then apply it to the fold's validation portion. Avoid leakage from validation or test data.
5. Handle failed or singular QDA fits transparently; do not silently replace them with another classifier. Report unavailable candidates and the reason.
6. After selection, refit the selected model and its preprocessing on all training observations. Evaluate it exactly once on the reserved test set. Report test misclassification rate and, where useful, a confusion matrix. Do not use the test result to revise the model.
7. Keep conclusions proportional to the evidence. Explain the main model comparison, covariance assumptions, bias-variance trade-off, and limitations such as sample size, class imbalance, split variability, or lack of external validation when relevant. Do not claim causal or clinical validity from predictive performance alone.

# Required one-page report
Produce a clearly readable report of at most one printed page. It must include:
- dataset, response, predictors/coding, split proportions, random seed, and cross-validation design;
- a compact table of candidate models/settings and cross-validation misclassification rates, with the selected model clearly identified;
- at least one readable figure comparing cross-validation error across candidates;
- numerical fitting/evaluation results, including the selected model's test misclassification rate and a test confusion matrix;
- a concise description of the selected model, main findings, and limitations.

Use clear titles, labeled axes, legible text, sensible rounding, and a restrained academic style. Keep the figure and table readable when printed. Do not exceed one page for the analysis report. Append the complete contents of this skill separately when requested.

# Final checks
Before reporting, verify that the test set was held aside before selection, all candidates used identical folds, preprocessing was fit within folds, the selected pipeline was refit on all training data, and the test set was evaluated only once. Report the actual seed, sample counts, model-selection rule, file size when requested, and any reproducibility limitations. Never invent numerical results; if execution is unavailable, provide runnable code and clearly label results as not yet computed.
