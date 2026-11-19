# Course requirements and implementation checklist

Source: team-provided Project_Fall2026.pdf, STAT GU4205/GR5205, five pages.
The original course document remains authoritative. This checklist paraphrases
its requirements; proposed implementation choices are labeled separately.

## Required Project Description: November 20, 2026

- [ ] Names and UNIs of 3-5 teammates.
- [x] Collect real data and document its source (initial audit completed).
- [x] Describe the collected data in the generated initial report.
- [x] Generate insightful descriptive statistics and incorporate them into the initial report.
- [x] Generate at least four informative plots, with four variables shown in Figure 4.
- [x] Explain the statistics and plots in the initial report.
- [x] State research objectives/questions in the EDA report and analysis plan.

The initial report is generated in reports/project_description/ as PDF, DOCX and
Markdown. It is not yet ready to submit: team names/UNIs remain blank, and the
team must review any additional classroom instructions.

## Final submission

The PDF says the final deadline is TBA, likely finals week. Confirm any later
instructor announcement. The project is worth 10% with extra-credit potential.

- [x] Typed, organized ten-page report with labeled graphs generated in reports/final_report/.
- [x] Organized code and a separate code archive prepared; the team still needs to submit them.
- [x] Do not paste the entire script into the report appendix.
- [ ] Assess completeness, correctness, organization/neatness and creativity.

The recommended inferential-report template is flexible; to cover it fully:

- [x] Introduction and focused EDA.
- [x] Data collection, variables and sample size.
- [x] Final model, R summary and transformations/interactions explained.
- [x] Relevant hypothesis tests with written answers to the research questions.
- [x] Model-selection rationale and relevant supporting output.
- [x] Diagnostic plots and validation, with remaining limitations stated.
- [x] Test MSPR compared with the fitted model's MSE on the same response scale.
- [x] Influential observations and host deletion checks; no automatic exclusions.

R is our implementation choice; Python and certain other languages are also
allowed. The PDF prohibits Excel, Minitab and SPSS for the analysis. It discourages
pure machine-learning approaches such as neural networks and random forests.
Projects in the Other category require instructor/TA approval; this project is
planned within the recommended regression-inference category. The PDF allows
AI-assisted sourcing of real data; follow any additional course AI rules.

## Team implementation commitments

- [x] Fixed source file, checksum and repeatable import/audit.
- [x] Preserve raw data; flag exclusions and missingness explicitly.
- [x] Generate every current figure and analytical statistic with R; retain this rule for later stages.
- [x] Fit training candidates after reviewing sample coverage and variable definitions.
- [x] Generate training diagnostics, inferential tests, property-label sensitivity and influence checks.
- [x] Document one training-driven functional-form revision and host-level internal validation.
- [x] Freeze the final specification before evaluating reserved hosts; reruns only reproduce it.
- [x] Keep the report, including appendix, to ten pages.
- [x] Run the complete pipeline and cross-check the prepared report against its outputs.

The final work is in `reports/final_report/` and `reports/final_analysis/`.
Private room remains in the primary analysis and the property-label sensitivity
subset. The earlier training report is preserved as a historical artifact.
Names/UNIs, team review, submission and any updated classroom instructions remain
the team's responsibility. Completion of the analytical sections does not mean
all regression assumptions are satisfied.
