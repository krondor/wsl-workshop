#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#


# Define server logic required to draw a histogram
shinyServer(function(input, output) {
  system('pwd')
  library(DT)
  library(shiny)
  library(data.table)
  library(ggplot2)
  library(randomForest)
  library(jsonlite)
  
  ## load data and model
  message("test")
  newEventsDF <- read.csv("./new_brake_events.csv")
  oldEventsDF <- read.csv("./historical_brake_events.csv")
  
  brakeEventModel <- readRDS(file = "./brakeEventModel.rds")
  
  ## Render plot and conditional statement for new points
  output$plot <- renderPlot({
    if(input$newPoints == F){
      ggplot(oldEventsDF, aes_string(x=input$xvar, y=input$yvar)) + 
        geom_point(aes(color = road_type, shape = road_type), size = 2) +
        theme_minimal()
    } else
      ggplot(oldEventsDF, aes_string(x=input$xvar, y=input$yvar)) + 
      geom_point(aes(color = road_type, shape = road_type), size = 2) +
      geom_point(data = newEventsDF, aes_string(x = input$xvar, y = input$yvar), size = 4, shape = 8) +
      theme_minimal()
    
  })
  
  ## Render table with new records
  output$table <- DT::renderDataTable(DT::datatable({
    
    data <- newEventsDF[, c("VIN", "brake_time_sec", "brake_distance_ft",
                            "road_type", "travel_speed", "abs_event", "braking_score")]
    
    data
    
  }))
  
  ## Get predictions based on loaded R model
  toPredict <- eventReactive(input$getPrediction,{
    
    toPredictDF <- data.frame(
      brake_time_sec = input$brakeTime,
      brake_distance_ft = input$brakingDist,
      road_type = as.factor(input$roadType),
      braking_score = input$brakeScore,
      brake_pressure20pct = input$brakeP20,
      brake_pressure40pct = input$brakeP40,
      brake_pressure60pct = input$brakeP60,
      brake_pressure80pct = input$brakeP80,
      brake_pressure100pct = input$brakeP100,
      abs_event = input$absEvent,
      travel_speed = input$speed)
    
    levels(toPredictDF$road_type) <- c("residential", "highway", "main road")
    
    prediction <- predict(brakeEventModel, toPredictDF)
    
    prediction
    
    
  })  
  
  ## Get predictions based on deployed model & REST API
  toPredictAPI <- eventReactive(input$getPrediction,{
    
    toPredictDF <- data.frame(
      brake_time_sec = input$brakeTime,
      brake_distance_ft = input$brakingDist,
      road_type = as.factor(input$roadType),
      braking_score = input$brakeScore,
      brake_pressure20pct = input$brakeP20,
      brake_pressure40pct = input$brakeP40,
      brake_pressure60pct = input$brakeP60,
      brake_pressure80pct = input$brakeP80,
      brake_pressure100pct = input$brakeP100,
      abs_event = input$absEvent,
      travel_speed = input$speed)
    
    levels(toPredictDF$road_type) <- c("residential", "highway", "main road")
    
    ## Use generated code from model API
    curl_left <- "curl -k -X POST https://169.50.74.155/dmodel/v1/r-lab-test-rel/rscript/brakeevent-online/score -H \'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6InNpZG5leXAiLCJwYWNrYWdlTmFtZSI6InItbGFiLXRlc3QtcmVsIiwicGFja2FnZVJvdXRlIjoici1sYWItdGVzdC1yZWwiLCJpYXQiOjE1NDU4Njk2NTR9.sG9t_NrFqZIsl2tB34wYsVXNqYX313WDUxvdcLet-C-fbrv8-VTqAFftbtIv4E_x8TV49yWQUguT6UNJd9EKI8CdKqmb7uNJM96MXp_EZjnYUIxV1lljRE7felcfm_u_sre7UrAeslrBInOujVrkMzbEhFz2J_Gybj8VdZLVHyppC_iKXyRlhTyPkgsh9Jk-AhMoov-s0KNFOwWc4mEANE1ZrHxnXb1aySzA9RcYvbxWVdZ5G1A5nGEDi-VGoP6qdM_MjtTNvTBdogEHVPraq6IEYz-ng5ovHVZyMB4H9lhzuxw9wPw8MY50GWp_ipB6TEaIakoYQiVxkp0XitfV3g\' -H \'Cache-Control: no-cache\' -H \'Content-Type: application/json\' -d \'{\"args\":{\"input_json\":"
    curl_right <- "}}\'"
    
    request_body <- toJSON(toPredictDF)
    
    ## Make request
    response <- system(paste0(curl_left, request_body, curl_right), intern = T)
    
    ## turn back into DF
    prediction <- as.data.frame(fromJSON(unlist(fromJSON(response)[1])))
    
    results <- list(prediction = prediction, response = response)
    
  })  
  
  
  
  ## Render the loaded R model prediction in the UI
  output$predict <- renderPrint({
    toPredict()
    
  })
  
  ## Render the API response predictions in the UI
  output$APIplot <- renderPlot({
    
    ggplot(toPredictAPI()$prediction, aes_string(x=toPredictAPI()$prediction$classes, 
                                                 y=toPredictAPI()$prediction$probabilities, 
                                                 fill = toPredictAPI()$prediction$classes)) + 
      geom_bar(stat = "identity") +
      labs(x = "Classes", y = "Probabilities") +
      theme_minimal() +
      coord_flip()
    
  })
  
  ## Show JSON response
  output$APIpredict <- renderPrint({
    toPredictAPI()$response
  })
})

