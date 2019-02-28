#
#  The R code in this script is mostly the same as the code in the DriverClassification Jupyter notebook.  The only differences are:
#  1. Where the csv file is read from.  In a notebook, the csv file is read from the project datasets folder.  In RStudio, the csv file is 
#     read from the RStudio file system.  Those are two different locations.  While the files in the project datasets folder are
#     not visible in RStudio, you can still read then programmatically, like this:
#
#     df.data.1 <- read.csv(paste(Sys.getenv("DSX_PROJECT_DIR"),'/datasets/historical_brake_events.csv',sep=""))
#
#  2. The graphs rendered by ggplot are displayed in the Plots tab on the right
#
#  As you can see, the ability to include markdowns in a Jupyter notebook make the quality of the documentation there much richer.  
#  In RStudio, you can inspect the value of each variable listed in the Global Environment on the left
#

######################################
#
#  Read Data in RStudio
#
######### Action Required ############
# 1.  In the File tab on the lower right side, click into the demoBrakeEvents folder
# 2.  Click historical_brake_events.csv and select Import Data (continue reading to step 3 before you execute this step)
# 3.  Copy the code in "Code Preview" (lower right section) and paste the code below.  
# 4.  Replace the variable "historical_brake_events" with "brakeEventDF" to represent the R dataframe that that data is read into
#
#     The code should look like this:
#      library(readr)
#      brakeEventDF <- read_csv("demoBrakeEvents/historical_brake_events.csv")
#      View(brakeEventDF)
#
#  5. To execute the code, select the lines you pasted below and click the "Run" button. You may explore all the Run option in the "Code" drop-down menu.
#
###################################################

# Insert code here



head(brakeEventDF)
######################
#  Summary statistics
#
#  Select the lines of code in this section and click the Run button.  The output is displayed in the Console
######################

library(magrittr)
library(dplyr)
print("Summary Statistics by Event Type")
group_by(brakeEventDF, type) %>% summarise(avg_braketime = mean(brake_time_sec), avg_brakedistance = mean(brake_distance_ft), avg_brakescore = mean(braking_score), abs_events = sum(abs_event))

print("Summary Statistics by Event Type and Road Type")
aggDF <- group_by(brakeEventDF, type, road_type) %>% summarise(avg_braketime = mean(brake_time_sec), avg_brakedistance = mean(brake_distance_ft), avg_brakescore = mean(braking_score), abs_events = sum(abs_event))
aggDF

###################
#  Visualization
#
#  Select the lines of code in this section and run them.  The output is displayed in the Plots section to the right.  
#  Note:  You can navigate through the three graphs using the arrows in the upper left corner of the plots tab
##################
library(ggplot2)
options(repr.plot.width = 12, repr.plot.height = 3)

ggplot(brakeEventDF, aes(x = brake_time_sec, color = type, fill = type)) + 
  geom_density(alpha = 0.5) +
  labs(x = "Braking Time (seconds)", y = "Observation Density", title = "Distribution of Brake Time by Type") +
  theme_minimal()

ggplot(sample_frac(brakeEventDF, .33), aes(x = brake_distance_ft, y = braking_score)) + 
  geom_point(aes(shape = road_type, color = type), size = 2) +
  scale_shape_manual(values=c(3, 5, 8)) +
  geom_point(color = 'black', size = 0.35, aes(shape = road_type)) +
  labs(x = "Braking Distance (feet)", y = "Braking Score", title = "Braking Score by Distance (ft)") +
  theme_minimal()

ggplot(aggDF, aes(x = road_type, y = abs_events)) + 
  geom_bar(aes(fill = type), stat = 'identity') + 
  coord_flip() +
  labs(x = "# of ABS Events", y = "Road Type", title = "ABS Events by Road Type and Event Type") +
  theme_minimal()

#######################
#
#  Modeling
#
#  Review and select the lines of code in this section to run
#######################

# Split data into Train and Test sets
## set the seed to make your partition reproductible
set.seed(22)

## Get row names for random sample of 70% of data
trainingRows <- row.names(brakeEventDF) %in% row.names(sample_frac(brakeEventDF, 0.7)) 

## Convert character columns to factor
brakeEventDF$type <- as.factor(brakeEventDF$type)
brakeEventDF$road_type <- as.factor(brakeEventDF$road_type
)
## Split into train/test dataframes
trainingDF <- brakeEventDF[trainingRows, ]
testingDF <- brakeEventDF[!trainingRows, ]

## Check dimensions, should add up to 2100
paste("Rows in training set: ", dim(trainingDF)[1])
paste("Rows in test set: ", dim(testingDF)[1])

#
# Use the Caret package to streamline the process of creating R models
#
library(caTools)
library(randomForest)
library(caret)


# Select features, train model, evaluate accuracy
## Preserve VINs to add on after modeling
vins <- trainingDF$VIN

## Select columns for modeling
trainingDF <- select(trainingDF, type, brake_time_sec, brake_distance_ft, road_type, braking_score, 
                     brake_pressure20pct, brake_pressure40pct, brake_pressure60pct,
                     brake_pressure80pct, brake_pressure100pct, abs_event, travel_speed)

## Using `caret` package
brakeEventModel <- train(type ~ .,
                         data = trainingDF,
                         method = "rf",
                         ntree = 50,
                         proximity = TRUE)
## Load test set
testingDF <- read.csv('../datasets/testdata.csv')
testingDF <- select(testingDF, -VIN)

print("Confusion Matrix for Testing Data:")
table(predict(brakeEventModel, select(testingDF, -type)), testingDF$type)

#######################
#
# Model Export
#
# In this section, you will learn the difference of saving the model in WSL RStudio file system versus WSL repository.
#
# Save model in the WSL RStudio directory for use in our Shiny app. When we save to the file system, we will not be able to take advantage of 
# the built-in model deployment capabilties. However, we use this option because we can quickly integrate it with the Shiny application. 
# To integrate with the model that has been saved in a WSL repository, we will need to deploy it for online scoring in Deployment Manager and 
# invoke it from Shiny via REST API.
#
#########################

saveRDS(object = brakeEventModel, file = "demoBrakeEvents/brakeEventModel.rds")

######### Action Required ############
#  Verify that the demoBrakeEvents\brakeEventModel.rds has the current timestamp
#


#
#  Save model in WS repository
#
#  Take note of the path that is displayed when you save the model
#
library(modelAccess)
library(jsonlite)

saveModel(model = brakeEventModel, name = "BrakeEventClassifier", test_data=testingDF)

######### Action Required ############
#
#  1. Replace {model_path} in the code below with the path to the model, as displayed after saving the model. 
#     Note: You must add "model" at the end of the path. e.g. "/models/BrakeEventClassifier/1/model"
#

modelPath <- paste(Sys.getenv("DSX_PROJECT_DIR"),"{model_path}",sep="")
savedModel<-readRDS(modelPath)

# payload for scoring 
scoringDF <- data.frame(
  brake_time_sec = 40,
  brake_distance_ft = 120,
  road_type = as.factor("highway"),
  braking_score = 100,
  brake_pressure20pct = 1,
  brake_pressure40pct = 1,
  brake_pressure60pct = 0,
  brake_pressure80pct = 0,
  brake_pressure100pct = 0,
  abs_event = 1,
  travel_speed = 20)

# Make prediction
predictions <- predict(savedModel, scoringDF)
probabilities <- predict(savedModel, scoringDF, type="prob")
classes <- colnames(probabilities)

output <- list(classes, unname(probabilities, force=FALSE), predictions)
names(output) <- list("classes", "probabilities", "predictions")
json_output <- toJSON(output)
json_output


######### Action Required ############
#
#  Verify new versions of the BrakeEventClassifier model is saved
#
#  Go to the Models section of the project, verify that a new version of BrakeEventClassifier model is there
#


