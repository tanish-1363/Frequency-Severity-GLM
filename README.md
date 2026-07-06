This project is a pricing model for Property & Casualty (P&C) auto insurance built in R. It moves beyond basic flat-rate pricing by segregating driver risk and calculating premiums based on historical claim frequency and severity. Finally, the model is validated through decile risk-pooling and calibrated to ensure the expected portfolio cost matches actual historical losses.

## Data 
The model is built on the `dataCar` dataset from the `insuranceData` R package. It contains a portfolio of **67,856 one-year auto insurance policies** underwritten in 2004 and 2005. Of the total portfolio, exactly 4,624 policies (6.8%) incurred at least one claim, creating a real-world scenario.

### Data Dictionary
| Variable | Meaning |
| :--- | :--- |
| `numclaims` | Number of claims filed |
| `claimcst0` | Total claim payout ($) | 
| `exposure` | Policy duration (0.0 to 1.0) | 
| `veh_value` | Vehicle Value (in $10,000s) |
| `veh_body` | Vehicle Body Type (SEDAN, COUPE, TRUCK etc.) |
| `veh_age` | Vehicle Age Bracket (1=Newest to 4=Oldest) |
| `gender` | Driver Gender (M/F) |
| `agecat` | Driver Age Bracket (1=Youngest to 6=Oldest) | 
| `area` | Geographic Density (A to F) |

* **Language:** R
* **Libraries:** `insuranceData`, `dplyr`, `ggplot2`
 

### 1. Data Engineering & Baseline Profiling
Before the algorithm can calculate who is a high-risk driver, it needs to mathematically define what an "average" driver looks like. This establishes a control group to anchor the rest of the pricing model. All future price adjustments are calculated relative to this profile.
* **The Baseline Driver:** Middle-Aged (Age Category 3), driving a Sedan, located in Area C (Average density). 
* **Exposure Adjustment:** Many policies in this dataset were written or canceled mid-year. If the model treats a 6-month policy exactly the same as a full 12-month policy, the risk calculations get completely distorted. A mathematical offset `offset(log(exposure))` parameter is applied ensuring the model calculates an *annualized* claim rate.

### 2. Frequency Modeling (Poisson GLM)
The first model predicts **how often** a policyholder will crash. Because claim counts are discrete, non-negative integers, a Poisson distribution with a log-link function is used.

**Equation:** $$\ln(\text{Number of Claims}) = a_1(\text{Vehicle Body}) + a_2(\text{Vehicle Age}) + a_3(\text{Gender}) + a_4(\text{Area}) + a_5(\text{Age Category}) + \ln(\text{Exposure})$$

**Mathematical Signal Extraction:**
The model successfully extracted highly significant predictive signals (P < 0.001) across multiple variables.

| Variable | Raw Estimate | Multiplier | Statistical Significance | Interpretation |
| :--- | :---: | :---: | :---: | :--- |
| **Intercept (Base)** | -1.754 | 0.173 | `< 2e-16 ***` | The baseline driver has a 17.3% chance of an annual claim. |
| **veh_bodyCOUPE** | 0.428 | 1.535 | `0.0003 ***` | Coupes crash **53.5% more frequently** than Sedans. |
| **agecat1 (Young)** | 0.229 | 1.259 | `1.38e-05 ***` | Young drivers crash **25.9% more frequently** than middle-aged. |
| **agecat5 (Older)** | -0.243 | 0.784 | `6.69e-07 ***` | Older drivers crash **21.6% less frequently** than baseline. |

### 3. Severity Modeling (Gamma GLM)
The second model predicts **how much** the mechanic bill will cost when a crash occurs. The dataset is filtered exclusively to policyholders with a claim greater than $0. Because repair costs are continuous, strictly positive, and highly right-skewed, a Gamma distribution with a log-link function is used.

**Equation:** $$\ln(\text{Claim Amount}) = a_1(\text{Vehicle Body}) + a_2(\text{Vehicle Age}) + a_3(\text{Gender}) + a_4(\text{Area}) + a_5(\text{Age Category})$$

**Mathematical Signal Extraction:**

| Variable | Raw Estimate | Multiplier | Statistical Significance | Interpretation |
| :--- | :---: | :---: | :---: | :--- |
| **Intercept (Base)** | 7.353 | 1562.42 | `< 2e-16 ***` | The baseline driver's average crash costs $1,562. |
| **genderM (Male)** | 0.172 | 1.189 | `0.0011 **` | Male crashes are **18.9% more expensive** to repair. |
| **agecat1 (Young)** | 0.276 | 1.319 | `0.0030 **` | Young driver crashes cause **31.9% more dollar damage**. |
| **areaF (High Density)**| 0.334 | 1.397 | `0.0039 **` | Urban/dense area crashes cost **39.7% more**. |

### 4. Pure Premium Calculation
The final risk cost for any driver in the portfolio is calculated using 

**The Pricing Equation:** `Expected Frequency × Expected Severity = Pure Premium`

## Model Validation & Calibration

### Out-of-Sample Validation (A/E Lift Chart)
To test the engine's predictive validity without looking at individual mathematical variance, the portfolio is ranked by Pure Premium and chopped into 10 equal Risk Deciles.

<img width="1377" height="850" alt="image" src="https://github.com/user-attachments/assets/8dfc3d7f-0534-4c67-9356-ad9ebfd30cfb" />

### Portfolio Calibration (Mathematical Off-Balance)
A raw statistical model is rarely ready for street deployment without final calibration. The total portfolio Actual-to-Expected (A/E) ratio must be calculated to measure systemic bias.

* **Total Portfolio A/E Ratio = 0.936293**

This ratio indicates that the raw GLM engine slightly over-predicted the total portfolio costs by roughly 6.4%. To finalize the production tariff, an **Off-Balance Factor of 0.936** is systematically applied across all premiums. This mathematically guarantees that the total money collected by the insurance carrier perfectly matches the total historical losses (Balanced A/E = 1.000), ensuring the product is aggressively priced and market-competitive.
