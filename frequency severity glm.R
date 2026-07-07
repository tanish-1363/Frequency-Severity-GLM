#loading the required library
library(insuranceData)

#loading the inbuilt data Car
data(dataCar)
?dataCar

#converting categorical data into factors
dataCar$veh_body <- as.factor(dataCar$veh_body)
dataCar$veh_age <- as.factor(dataCar$veh_age)
dataCar$gender <- as.factor(dataCar$gender)
dataCar$area <- as.factor(dataCar$area)
dataCar$agecat <- as.factor(dataCar$agecat)

#locking in the baseline profile
# Base Vehicle: Sedan
# Base Location: Area C (Average density)
# Base Age: Category 3 (Middle-aged)
dataCar$veh_body <- relevel(dataCar$veh_body,ref="SEDAN")
dataCar$area <- relevel(dataCar$area,ref="C")
dataCar$agecat <- relevel(dataCar$agecat,ref="3")

#filtering out the broken data
dataCar <- subset(dataCar,exposure>0)

#fitting the poisson frequency model 
freq_model <- glm(numclaims ~ veh_body + veh_age + gender + area + agecat + offset(log(exposure)), 
                  data = dataCar, 
                  family = poisson(link = "log"))

#converting into actual multipliers 
round(exp(coef(freq_model)),3)

#summary of the model
summary(freq_model)

#filtering out policyholder who have had a claim
severity_data <- subset(dataCar, claimcst0>0)

#fitting a severity model 
sev_model <- glm(claimcst0 ~ veh_body + veh_age + gender + area + agecat, 
                 data = severity_data, 
                 family = Gamma(link = "log"))

#converting into actual multipliers 
round(exp(coef(sev_model)),3)

#summary of the model
summary(sev_model)

#calculating pure premium
#pure premium = frequency x severity
dataCar$pred_freq <- predict(freq_model, newdata = dataCar, type = "response") / dataCar$exposure
dataCar$pred_sev <- predict(sev_model, newdata = dataCar, type = "response")
dataCar$pure_premium <- dataCar$pred_freq * dataCar$pred_sev

head(dataCar[, c("veh_body", "agecat", "gender", "pred_freq", "pred_sev", "pure_premium")], 8)

library(ggplot2)
library(dplyr)

#divides data into 10 groups (safest to deadliest)
lift_data <- dataCar %>%
  mutate(decile = ntile(pure_premium, 10)) %>%
  group_by(decile) %>%
  summarise(
    Actual_Cost = sum(claimcst0),        
    Expected_Cost = sum(pure_premium*exposure),
    Number_Claims = sum(numclaims),
    Max_Claim = max(claimcst0),
    Sum_Max_10_Claim = sum(head(sort(claimcst0,decreasing = T),10))
  )
#plotting actual and expected lift for 10 groups 
ggplot(lift_data, aes(x = factor(decile))) +
  geom_line(aes(y = Actual_Cost, group = 1, color = "Actual Cost (Reality)"), size = 1.2) +
  geom_point(aes(y = Actual_Cost, color = "Actual Cost (Reality)"), size = 3) +
  geom_line(aes(y = Expected_Cost, group = 1, color = "Expected Cost (Your Model)"), size = 1.2, linetype = "dashed") +
  geom_point(aes(y = Expected_Cost, color = "Expected Cost (Model)"), size = 3) +
  scale_color_manual(values = c("Actual Cost (Reality)" = "darkorange", 
                                "Expected Cost (Your Model)" = "lightblue")) +
  labs(title = "Actual vs. Expected (A/E) Lift",
       subtitle = "Validating Predictive Accuracy Across 10 Risk Deciles",
       x = "Risk Decile (1 = Safest Drivers, 10 = Unsafest Drivers)",
       y = "Total Portfolio Dollar Cost",
       color = "Legend") +
  theme_minimal() +
  theme(legend.position = "bottom",
        text = element_text(size = 12),
        plot.title = element_text(face = "bold", size = 16))

#actual expected ratio
AE_ratio <- sum(dataCar$claimcst0)/sum(dataCar$exposure*dataCar$pure_premium)
AE_ratio
