---
name: svm-report
description: Explicitly invoked workflow for selecting and reporting SVM classifiers.
---

# Invocation
Use this skill only when the user explicitly invokes `svm-report`. Keep dataset details in the invocation, not here.

# Analysis
1. Check sample size, response classes, predictor types, missingness, and whether SVM is appropriate; state limitations.
2. Consider suitable kernels (at least linear and radial when appropriate); justify each choice.
3. Identify tuning parameters, search a justified grid, and use a reproducible method such as stratified cross-validation.
4. Reuse identical folds across candidates. Fit scaling, imputation, and other preprocessing on each fold's training portion only.
5. Select the final model using a stated validation metric. Keep any final test set untouched until model selection is complete.
6. Produce a compact, labeled figure and table comparing candidates and explaining the selected settings.
7. Interpret the fitted model cautiously and report key numerical results, including validation performance and final test performance if a test set is used.
8. Check data coding, fold consistency, calculations, selected settings, and agreement between the figure, table, and narrative.

# Report
Prioritize the evidence that justifies the final model. Keep the report to no more than one printed page at 11-point font, with readable figures and tables. Never invent results; if the data or execution environment is unavailable, state what is missing and request the needed file or provide reproducible code without fabricated numbers.
