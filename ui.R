#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)
library(plotly)
library(leaflet)

# Define UI for application that draws a histogram
shinyUI(fluidPage(
  
  titlePanel('Helsinki Region Statistics'),
  
  em('Open data by Tilastokeskus 2018'),
  br(),
  p('Exploring statistics of each Helsinki region district by clicking on the map, and you can choose which ciy and metric to be shown'),
  br(),
  br(),
  
  fluidRow(
    column(width = 2,
           verticalLayout(
             radioButtons(inputId = 'city',
                         label = 'City',
                         choices = c('Capital Region','Helsinki','Espoo','Vantaa','Kauniainen')),
             radioButtons(inputId = 'metric',
                          label = 'Map Metrics',
                          choices = c('Population (2016)','Median Income (2015)'))
           )
    ),
    
    column(width = 3, 
           plotlyOutput('gender', height = '250')),
    column(width = 4,
           plotlyOutput('age', height = '300'))), 
  
  fluidRow(width = 12,
           leafletOutput('map', height = '600'))
  
))
