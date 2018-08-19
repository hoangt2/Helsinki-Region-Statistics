library(shiny)
library(rgdal)
library(dplyr)
library(leaflet)
library(reshape2)
library(stringr)
library(ggplot2)
library(plotly)

######### Data manipulation ############
# Read data file
paavo <- read.csv('paavo_data.csv', header=T, sep = ',', colClasses = c('postal.code'='factor'))

# Read shapefile
pks_map = readOGR('./PKS_postinumeroalueet_2017_shp.shp', encoding = 'latin1')

# spTransform allows us to convert and transform between different mapping projections and datums. 
# This line of code is telling R to convert our Neighborhoods file to longitude/latitude projection 
# and World Geodetic System 1984 datum - a global coordinate (GPS) system used by Google Maps 
# (the initial object was set to a Lambert Conic Conformal projection and a NAD83 datum, as well as a GRS80 ellipsoid)

pks_map <- spTransform(pks_map, CRS("+proj=longlat +datum=WGS84"))

pks_map <- merge(pks_map, paavo, by.x = 'Posno', by.y='postal.code')

#Extract this data to use for statistics plots
pks_data <- pks_map@data 

pks_data$city <- trimws(pks_data$city)

# Create additional data frame to summarize data for each region
city.summary <- na.omit(pks_data[,9:33]) %>% group_by(city) %>% summarise_all(funs(sum))
city.summary <- city.summary %>% bind_rows(c('city' = 'Capital Region', city.summary[,2:25] %>% summarise_all(funs(sum))))
colnames(city.summary)[1] <- 'Nimi'

pks_data <- pks_data %>% bind_rows(city.summary) # Append the summary data to the dataset

# Color theme for the plot
finnish.blue <- 'rgb(0,46,162)'


########## Server File Functions #########
shinyServer(function(input, output) {
  
  # Create a function that plot the map, taking arguments triggered by observed events from the side bar 
  render.map <- function(metric, city_map, color.palette, border.color, legend.title){
    output$map <- renderLeaflet({
      
      bins <- c(seq(0, round(max(metric, na.rm = TRUE)/1000)*1000, by = 5000), Inf)
      pal <- colorBin(color.palette, domain = metric, bins = bins)
      
      # Create HTML popups
      popups <- sprintf(
        "<strong>%s</strong><br/>Population: %s<br/>Median income: %s EUR/year",
        city_map@data$Nimi, 
        format(city_map@data$total.pop, big.mark = ','), 
        format(city_map@data$median.income, big.mark = ',')
      ) %>% lapply(htmltools::HTML)
      
      
      leaflet() %>% addProviderTiles(providers$CartoDB.Positron) %>% 
        addPolygons(data = city_map,
                    layerId = city_map@data$Nimi, 
                    label = city_map@data$Nimi,
                    popup = popups,
                    fillColor = ~pal(metric),
                    fillOpacity = 0.7, 
                    color = border.color,
                    dashArray = '3',
                    weight = 1,
                    
                    #Hightlight a shape when hovering
                    highlight = highlightOptions(
                      weight = 4,
                      color = 'blue',
                      dashArray = "",
                      fillOpacity = 0.9,
                      bringToFront = TRUE)
                    
                    
        )%>% addLegend(pal = pal,
                       values = metric, 
                       opacity = 0.7, 
                       title = legend.title,
                       position = "topleft")
    })
  }
  
  # Create a function that plot the statistics of the clicked region (using Plotly)
  render.plots <- function(district){
    
    district.data <- pks_data[pks_data$Nimi == district,]
    
    # Gender plot
    output$gender <- renderPlotly({
      
      gender <- district.data[,c('males','females')]
      gender <- melt(gender, id.vars = NULL)
      names(gender) <- c('gender', 'count')
      gender <- na.omit(gender)
      
      plot_ly(data = gender, labels = ~gender, 
              values = ~count, type = 'pie', sort = FALSE,
              textposition = 'inside',
              insidetextfont = list(color = finnish.blue),
              textinfo = 'label+percent',
              marker = list(colors = c('white','white'),
                            line = list(color = finnish.blue, width = 2)),
              showlegend = FALSE) %>% 
        layout(title = 'Gender')
    })
    
    # Histogram of age groups
    output$age <- renderPlotly({
      
      age <- district.data[,13:32]
      age <- melt(age, id.vars = NULL)
      names(age) <- c('age','count')
      age <- na.omit(age)
      age$age <- str_sub(age$age, start = 5L)
      age$age <- str_replace(age$age, '\\.','-')
      age$age <- str_replace(age$age, '85-plus','85+')
      
      plot_ly(data = age, x = ~age, 
              y = ~count, type = 'bar',
              marker = list(color = 'white',
                            line = list(color= finnish.blue, width = 2))
      ) %>% layout(title = 'Age', 
                   xaxis = list(title = '', categoryorder = 'array', categoryarray = age$age),
                   yaxis = list(title = ''))
    })
  }
  
  # ReactiveValues to keep track of the clicked region
  clicked.region <- reactiveValues()
  
  
  # Plot the map when we change the inputs of the side bar 
  observeEvent(c(input$metric, input$city), {
    
    # Plot when user chooses the city
    clicked.region <- input$city
    render.plots(clicked.region)
    
    # Plot the map when user chooses the city & the metric
    city_map <- pks_map
    if(input$city != 'Capital Region'){
      city_map <- subset(pks_map, Kunta == input$city) 
    }
    
    if (input$metric == 'Population (2016)'){
      render.map(metric = city_map@data$total.pop, 
                 city_map = city_map,
                 color.palette = 'YlOrRd', 
                 border.color = 'grey',
                 legend.title = 'Population')
    } else {
      render.map(metric = city_map@data$median.income, 
                 city_map = city_map,
                 color.palette = 'YlGnBu', 
                 border.color = 'white',
                 legend.title = 'Median Income (EUR/year)')
    }
  })
  
  
  
  
  # Events when a district is clicked  
  observeEvent(input$map_shape_click, {
    clicked.region <- input$map_shape_click$id
    
    if (!is.null(clicked.region)){
      render.plots(clicked.region)
    }
    
  })
  
})
