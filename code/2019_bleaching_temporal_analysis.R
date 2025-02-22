#### hawaii coral bleaching analysis: temporal trends ####
## written by: morgan winston

## this script uses cluster-level data described & linked to here: {https://www.fisheries.noaa.gov/inport/item/64324}
## code performs the following: investigates differences b/w 2015 & 2019 in the MHI/2014 & 2019 in the NWHI; creates figures

### initialization ####
# load packages & useful functions
library(ggplot2) # for plotting figures
library(plotrix) # for calculating standard error
library(lme4) # for running linear mixed models
library(nlme)
library(emmeans) # for tukey post hoc tests
library(merTools) # for running predictInterval to get CIs for mixed model
library(gridExtra) # for grid.arrange() to combine multiple plots
g_legend<-function(a.gplot){ # function to extract legend from a plot
  tmp <- ggplot_gtable(ggplot_build(a.gplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)}
'%!in%' <- function(x,y)!('%in%'(x,y)) # the opposite of %in%


# set working directory & load data
setwd("C:/Users/Morgan.Winston/Desktop/MHI NWHI 2019 Coral Bleaching/Data/Bleaching Assessments/Combined/For InPort/Environmental Drivers")
hcbc <- read.csv("HCBC_2019_ClusteredData.csv")

#### prep data ####
## assign regions
hcbc$Region_Name <- NA
for(i in c(1:nrow(hcbc))){
  if(hcbc$Island_Name[i] %in% c("French Frigate Shoals", "Lisianski", "Pearl and Hermes", "Kure")){
    hcbc$Region_Name[i] <- "NWHI" 
  }
  else{
    hcbc$Region_Name[i] <- "MHI"
  }
}
# square-root transform response variable
hcbc$PctBleached_mean_sqrt <- sqrt(hcbc$CoralBleached_Perc_mn)

# only working with zones (MHI)/islands (NWHI) surveyed in both years (and have to meet min sample size of clustered obs per depth bin per zone)
## ^ subsetting already done, use weighting column here
hcbc <- hcbc[ which(!is.na(hcbc$Weights_TemporalAnalysis)),]

#### data analysis ####
# a. island differences 2015 v 2019 (MHI only) ####
hcbc_mhi <- hcbc[ which(hcbc$Region_Name == "MHI"),]
str(hcbc_mhi)
hcbc_mhi$Obs_Year <- as.factor(hcbc_mhi$Obs_Year)
hcbc_mhi$Island_Name <- droplevels(hcbc_mhi$Island_Name) # drop extra levels that are kept after subsetting
hcbc_mhi$ZoneName <- droplevels(hcbc_mhi$ZoneName)

# mixed effect model
bl_lm <- lmer(PctBleached_mean_sqrt ~ Obs_Year*ZoneName + (1|Island_Name), data = hcbc_mhi, weights = Weights_TemporalAnalysis) # full model for LRT comparison
summary(bl_lm)
## model fit:
plot(bl_lm) 
qqnorm(resid(bl_lm))

# likelihood ratio tests
bl_lm_yr <- lmer(PctBleached_mean_sqrt ~ Obs_Year + (1|Island_Name), data = hcbc_mhi, weights = Weights_TemporalAnalysis)
bl_lm_zone <- lmer(PctBleached_mean_sqrt ~ ZoneName + (1|Island_Name), data = hcbc_mhi, weights = Weights_TemporalAnalysis)
bl_lm_null <- lmer(PctBleached_mean_sqrt ~ 1 + (1|Island_Name), data = hcbc_mhi, weights = Weights_TemporalAnalysis)

anova(bl_lm, bl_lm_null, test = "Chisq") # tests interaction
anova(bl_lm_yr, bl_lm_null, test = "Chisq") # tests year
anova(bl_lm_zone, bl_lm_null, test = "Chisq") # tests zone

# post hoc tests:
posthoc_bl <- emmeans(bl_lm, list(pairwise ~ ZoneName + Obs_Year), adjust = "tukey") # ignore pairs that are not same zone compared between years
p_bl <- as.data.frame(posthoc_bl$`pairwise differences of ZoneName, Obs_Year`)
p_bl[ which(p_bl$p.value < 0.05),]
# zones with significant differences between years: Hawaii NW, Hawaii SW, Maui W - add these to plot

# mean bleaching per island
aggregate(hcbc_mhi$CoralBleached_Perc_mn, by = list(Island = hcbc_mhi$Island_Name, Obs_Year = hcbc_mhi$Obs_Year), mean)

# get mhi predictions
head(hcbc_mhi)
new_mhi <- unique(hcbc_mhi[c("Island_Name","ZoneName","Obs_Year")])
bl_mhi <- lme(PctBleached_mean_sqrt ~ Obs_Year*ZoneName, random=~1|Island_Name, method = "ML", data=hcbc_mhi, weights = ~Weights_TemporalAnalysis)
new_mhi$predlme <- predict(bl_mhi, newdata = new_mhi, level = "0") # predicted value of bleaching based on mod
des = model.matrix(formula(bl_mhi)[-2], new_mhi) # predictor values
predvar = diag( des %*% vcov(bl_mhi) %*% t(des) ) 
new_mhi$lower = with(new_mhi, predlme - 2*sqrt(predvar) )
new_mhi$upper = with(new_mhi, predlme + 2*sqrt(predvar) )
new_mhi$Label <- sub('.*\\_', '', new_mhi$ZoneName)

# add post hoc significance to zone data
# zones with significant differences between years: Hawaii NW, Hawaii SW, Maui W 
new_mhi$group <- c("b", "NS", "NS", "NS", "b", "NS", "NS", "b", "NS",
                   "NS", "a", "a", "a", "NS", "NS", "NS", "NS", "NS")


# b. island differences 2014 v 2019 (NWHI only) #### 
hcbc_nwhi <- hcbc[ which(hcbc$Region_Name == "NWHI"),]
str(hcbc_nwhi)
hcbc_nwhi$Obs_Year <- as.factor(hcbc_nwhi$Obs_Year)

# two way ANOVA
bl_nwhi <- aov(PctBleached_mean_sqrt ~ Obs_Year*Island_Name, data = hcbc_nwhi, weights = Weights_TemporalAnalysis)
summary(bl_nwhi)
plot(bl_nwhi)

emmeans(bl_nwhi, list(pairwise ~ Obs_Year + Island_Name), adjust = "tukey") # tukey post-hoc test - NS as predicted from non-sig interaction effect above

predict.dat.nwhi <- as.data.frame(predict(bl_nwhi, hcbc_nwhi, interval = "confidence"))
predict.nwhi <- cbind(hcbc_nwhi, predict.dat.nwhi)
colnames(predict.nwhi)
colnames(predict.nwhi)[25] <- "predlme"
colnames(predict.nwhi)[26] <- "lower"
colnames(predict.nwhi)[27] <- "upper"
new_nwhi <- unique(predict.nwhi[c(1,2,20,25,26,27)])
new_nwhi$Label <- c("","","","")
new_nwhi$group <- c("NS","NS","NS","NS")


#### create plots ####
# ordering x axis
order <- c("PHR", "Lisianski", "Oahu", "Lanai", "Maui", "Hawaii")
order_full <- c("Pearl and Hermes", "Lisianski", "Oahu", "Lanai", "Maui", "Hawaii")
hcbc <- hcbc[order(factor(hcbc$Island_Name, levels = order_full)),] # order it
hcbc$Island_Name <- factor(hcbc$Island_Name, levels = order_full, labels = c("PHR", "LIS", "Oahu", "Lanai", "Maui", "Hawaii"))
hcbc$Region_Name <- factor(hcbc$Region_Name, levels = c("NWHI", "MHI"), labels = c("Northwestern Hawaiian Islands", "Main Hawaiian Islands"))
hcbc$Obs_Year <- as.factor(hcbc$Obs_Year)

# i. boxplots ####
# PLOT ISLAND LEVEL RESULTS 
# boxplot per island across archipelago
isl_raw_temp_plot <- ggplot(hcbc, aes(x = Island_Name, y = CoralBleached_Perc_mn)) +
  geom_jitter(aes(x = Island_Name, y = CoralBleached_Perc_mn, size = Weights_TemporalAnalysis, color = Obs_Year), width = 0.2) +
  geom_boxplot(aes(fill = Obs_Year), outlier.shape = NA, alpha = 0.6) +
  facet_grid(~Region_Name, scales = "free_x", space = "free") +
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.spacing = unit(0, "lines"), 
        strip.background = element_blank(),
        strip.placement = "outside",
        legend.position = "right",
        axis.line = element_line(color = "black"),
        panel.border = element_rect(colour = "black", fill=NA),
        axis.text.x = element_text(colour="black"), 
        axis.text.y = element_text(colour="black"),
        text = element_text(size = 12)
  ) + 
  scale_size_continuous(name = "Weight") +
  scale_fill_discrete(name = "Year") +
  scale_color_discrete(guide = F) +
  ylab(" % Bleached\n") +
  xlab("") 

# PLOT ZONE LEVEL RESULTS 
## boxplot per zone [MHI only]
hcbc$ZoneLabel <- NA
for(i in c(1:nrow(hcbc))){
  if(hcbc$Region_Name[i] == "Main Hawaiian Islands"){
    hcbc$ZoneLabel[i] <- substring(as.character(hcbc$ZoneName[i]), regexpr("_", as.character(hcbc$ZoneName[i])) + 1, nchar(as.character(hcbc$ZoneName[i])))
  }  
}

mhi <- hcbc[ which(hcbc$Region_Name == "Main Hawaiian Islands"),]
mhi$Obs_Year <- factor(mhi$Obs_Year, levels = c("2014","2015","2019"))
zone_raw_temp_plot_mhi <-
  ggplot(mhi, aes(x = ZoneName, y = CoralBleached_Perc_mn)) +
  geom_jitter(aes(x = ZoneName, y = CoralBleached_Perc_mn, size = Weights_TemporalAnalysis, color = Obs_Year), width = 0.2) +
  geom_boxplot(aes(fill = Obs_Year), outlier.shape = NA, alpha = 0.6) +
  facet_grid(~Island_Name, scales = "free_x", space = "free") +
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.spacing = unit(0, "lines"), 
        strip.background = element_blank(),
        strip.placement = "outside",
        legend.position = "bottom",
        axis.line = element_line(color = "black"),
        panel.border = element_rect(colour = "black", fill=NA),
        axis.text.x = element_text(colour="black"), 
        text = element_text(size = 18)#,
        # axis.ticks.y = element_blank()#,
        # axis.text.y = element_blank()
  ) + 
  scale_size_continuous(name = "Weight", limits = c(0.01,1)) +
  #scale_color_discrete(guide = F) +
  ylab("% Bleached \n") +
  xlab("") +
  scale_x_discrete(breaks = hcbc$ZoneName, labels =  hcbc$ZoneLabel) +
  scale_color_manual(values = c("#00BA38","#619CFF")) +
  scale_fill_manual(name = "Year", values = c("#00BA38","#619CFF")) +
  guides(color = F)
  scale_y_continuous(limits = c(-1,100))

# island level box plot in NWHI
nwhi_box <- ggplot(hcbc[ which(hcbc$Region_Name == "Northwestern Hawaiian Islands"),], aes(x = Island_Name, y = CoralBleached_Perc_mn)) +
  geom_jitter(aes(x = Island_Name, y = CoralBleached_Perc_mn, size = Weights_TemporalAnalysis, color = Obs_Year), width = 0.2) +
  geom_boxplot(aes(fill = Obs_Year), outlier.shape = NA, alpha = 0.6) +
  facet_grid(~Island_Name, scales = "free_x", space = "free") +
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.spacing = unit(0, "lines"), 
        strip.background = element_blank(),
        strip.placement = "outside",
        legend.position = "none",
        axis.line = element_line(color = "black"),
        panel.border = element_rect(colour = "black", fill=NA),
        axis.text.x = element_text(colour="black"), 
        axis.text.y = element_text(colour="black"),
        text = element_text(size = 18),
        axis.ticks.x = element_blank()
  ) + 
  scale_size_continuous(name = "Weight", limits = c(0.01,1)) +
  ylab(" % Bleached\n") +
  xlab("") + 
  scale_color_manual(values = c("#F8766D", "#619CFF")) +
  scale_fill_manual(name = "Year", values = c("#F8766D", "#619CFF")) +
  scale_x_discrete(labels = c("","")) +
  scale_y_continuous(limits = c(-1,100))

# island level across archipelago
boxplot_isl_leg <- ggplot(hcbc, aes(x = Island_Name, y = CoralBleached_Perc_mn)) +
  geom_jitter(aes(x = Island_Name, y = CoralBleached_Perc_mn, size = Weights_TemporalAnalysis, color = Obs_Year), width = 0.2) +
  geom_boxplot(aes(fill = Obs_Year), outlier.shape = NA, alpha = 0.6) +
  facet_grid(~Island_Name, scales = "free_x", space = "free") +
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.spacing = unit(0, "lines"), 
        strip.background = element_blank(),
        strip.placement = "outside",
        legend.position = "bottom",
        axis.line = element_line(color = "black"),
        panel.border = element_rect(colour = "black", fill=NA),
        axis.text.x = element_text(colour="black"), 
        axis.text.y = element_text(colour="black"),
        text = element_text(size = 18),
        axis.ticks.x = element_blank()
  ) + 
  scale_size_continuous(name = "Weight", limits = c(0.01,1)) +
  ylab(" % Bleached\n") +
  xlab("") + 
  scale_color_manual(values = c("#F8766D", "#00BA38", "#619CFF")) +
  scale_fill_manual(name = "Year", values = c("#F8766D", "#00BA38", "#619CFF")) + 
  guides(color = F)
box.leg <- g_legend(boxplot_isl_leg)

# finest scale possible across archipelago - boxplot
grid.arrange(arrangeGrob(nwhi_box, boxplot_isl_leg, nrow = 1, widths = c(1.1,3)), box.leg, nrow = 2, heights = c(9,1))

# ii. plot model predictions #### 
temp <- rbind(new_mhi, new_nwhi)
temp <- temp[order(factor(temp$Island_Name, levels = order_full)),] # order it

temp$Isl_Lab <- c("PHR", "PHR", "Lisianski", "Lisianski", 
                  "Oahu", "Oahu", "Oahu", "Oahu",
                  "Lanai", "Lanai", "Lanai", "Lanai",
                  "Maui", "Maui", "Maui", "Maui", "Maui", "Maui",
                  "Hawaii", "Hawaii", "Hawaii", "Hawaii")
temp$Isl_Lab <- factor(temp$Isl_Lab, levels = order)
temp$Obs_Year <- factor(temp$Obs_Year, levels = c("2014","2015","2019"))

leg_bar <- ggplot(temp, aes(ZoneName, predlme, fill = Obs_Year)) +  # make a fake plot to get the right legend
  facet_grid(~Isl_Lab, scales = "free_x", space = "free") +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9), width = 0.9, color="black") +
  theme(
    legend.direction = "horizontal",
    legend.text = element_text(size = 8),
    legend.title = element_text(size = 8)
  ) +
  scale_fill_discrete(name = "Year")
temp_leg <- g_legend(leg_bar)

nwhi_bar <- ggplot(temp[ which(temp$Island_Name %in% c("Pearl and Hermes", "Lisianski")),], aes(ZoneName, predlme, fill = Obs_Year)) + # nwhi plot
  facet_grid(~Isl_Lab, scales = "free_x", space = "free") +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9), width = 0.9, color="black") + 
  theme_bw() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.spacing = unit(0, "lines"),
        strip.background = element_blank(),
        strip.placement = "outside",
        strip.text = element_text(size = 8),
        axis.line = element_line(color = "black"),
        axis.ticks.x = element_blank(),
        text = element_text(size = 8),
        axis.text.y = element_text(colour="black")
  ) +
  xlab("") +
  ylab("Predicted % Bleached\n") +
  scale_y_continuous(limits = c(0,11.35), breaks = c(0,2.5, 5, 7.5, 10), labels = c(0,5,25,56,100)) +
  scale_x_discrete(breaks = temp$Zone, labels = temp$Label) +
  geom_text(data=temp[ which(temp$Island_Name %in% c("Pearl and Hermes", "Lisianski")),],aes(x=ZoneName,y=upper,
                                                                                             label=group),
            position = position_dodge(width = 1),
            vjust = -0.5, size = 2) +
  geom_errorbar(aes(ymin=lower, ymax=upper), width=.2,
                position=position_dodge(.9)) +
  scale_fill_manual(name = "Year", values = c("#F8766D","#619CFF"))

mhi_bar <- ggplot(temp[ which(temp$Island_Name %!in% c("Pearl and Hermes", "Lisianski")),], aes(ZoneName, predlme, fill = Obs_Year)) + #mhi plot
  facet_grid(~Isl_Lab, scales = "free_x", space = "free") +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9), width = 0.9, color="black") + 
  theme_bw() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.spacing = unit(0, "lines"),
        strip.background = element_blank(),
        strip.placement = "outside",
        strip.text = element_text(size = 8),
        axis.line = element_line(color = "black"),
        text = element_text(size = 8),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.title.y =element_blank()
  ) +
  xlab("") +
  ylab("Predicted % Bleached\n") +
  scale_y_continuous(limits = c(0,11.35), breaks = c(0,2.5, 5, 7.5, 10), labels = c(0,5,25,56,100)) +
  scale_x_discrete(breaks = temp$Zone, labels = temp$Label) +
  geom_text(data=temp[ which(temp$Island_Name %!in% c("Pearl and Hermes", "Lisianski")),],aes(x=ZoneName,y=upper,
                                                                                              label=group),
            position = position_dodge(width = 1),
            vjust = -0.5, size = 2) +
  geom_errorbar(aes(ymin=lower, ymax=upper), width=.2,
                position=position_dodge(.9)) +
  scale_fill_manual(name = "Year", values = c("#00BA38","#619CFF"))

setwd("C:/Users/Morgan.Winston/Desktop/MHI NWHI 2019 Coral Bleaching/Projects/2019 Manuscript/Drafts/For Submission - PLoS One/Figures")
tiff("Fig5.tiff", width = 2250, height = 1200, units = "px", res=300)
grid.arrange(arrangeGrob(nwhi_bar + theme(legend.position = "none"), mhi_bar +ylab("") + theme(legend.position = "none"), nrow = 1, widths = c(1,3)), temp_leg, heights = c(9,1))
dev.off()

