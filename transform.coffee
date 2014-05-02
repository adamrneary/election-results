_ = require('underscore')
utilities = require('./utilities')
fs = require('fs')
csv = require('csv')

# We initialize data variables with scope outside functions for convenience.
popData = []
evMvData = []

# This method loads our data from a raw format and then calls the analysis
# functions
readData = ->

  # Node's CSV parser loads data asynchronously as a stream. Since our data is
  # so small in this case, we'll just collect all the data and then carry on
  # once everything is in memory
  csv().from('./data/population.csv').on 'record', (row) ->
      popData.push row
    .on 'end', ->

      # Node's JSON parser loads data synchronously, so it's a bit simpler.
      evMvData = JSON.parse fs.readFileSync("./data/ev_mv.json", 'utf8')

      # All data is in hand. Fire analyses.
      # buildFig1()
      # buildFig2()
      # buildFig3()
      buildFig4()

# Figure 1: Population per Electoral Vote (2012 only)
buildFig1 = ->

  # Result array we'll write to disk
  popEv = []

  # We will scan through the parsed CSV for 51 states (including DC)
  _.each popData, (row) ->

    # The census CSV happens to put a '.' before each state name (thanks!)
    if row[0][0] is '.'

      # Store the state name, population, and population per electoral vote
      state = row[0].slice(1)
      state = 'D. C.' if state is 'District of Columbia'
      population = parseInt(row[5].replace(/,/g,''))
      ev = evMvData[2012]['states'][state]['ev']
      popEv.push
        'State': state
        'Population / Electoral Votes': parseInt(population/ev)
        'Electoral Votes': ev

  # Now we sort by population/ev to provide the context for the analysis
  popEv = _.sortBy popEv, (row) -> row['Population / Electoral Votes']

  # Write to disk as CSV (Excel can't open JSON) in the analysis folder
  fields = ['State', 'Population / Electoral Votes','Electoral Votes']
  utilities.writeCSV "./analysis/pop_ev.csv", popEv, fields

# Figure 2: Margin of Victory per Electoral Vote
buildFig2 = ->

  # Result array we'll write to disk
  mvEv = []

  # We will scan through the 2012 data for 51 states (including DC)
  _.each _.keys(evMvData[2012]['states']), (state) ->

    # Store the state name and margin of victory per electoral vote
    mv = evMvData[2012]['states'][state]['margin']
    ev = evMvData[2012]['states'][state]['ev']
    mvEv.push
      'State': state
      'Margin of Victory / Electoral Votes': parseInt(mv/ev)

  # Now we sort by mv/ev to provide the context for the analysis
  mvEv = _.sortBy mvEv, (row) -> row['Margin of Victory / Electoral Votes']

  # Write to disk as CSV (Excel can't open JSON) in the analysis folder
  fields = ['State', 'Margin of Victory / Electoral Votes']
  utilities.writeCSV "./analysis/mv_ev.csv", mvEv, fields

buildFig3 = ->

  # Result array we'll write to disk
  timeSeries = []

  # We will scan through the time series data
  _.each _.keys(evMvData), (year) ->

    safeStateVoterTally = 0

    # Within each year, scan through each state
    _.each _.keys(evMvData[year]['states']), (state) ->
      stateData = evMvData[year]['states'][state]

      # Tally up voter count from "safe states" (MV >= 20%)
      if stateData['margin_percent'] >= 20
        safeStateVoterTally += stateData['popular_vote']

    # Store the year and 2 percentages
    totalVote = evMvData[year]['overallPopularVote']
    timeSeries.push
      'Year': year
      'Very Safe State Voters': safeStateVoterTally / totalVote
      'Overall Margin of Victory': evMvData[year]['overallMargin'] / 100

  # Now we sort by year as readers will expect of time series analyses
  timeSeries = _.sortBy timeSeries, (row) -> row['Year']

  # Write to disk as CSV (Excel can't open JSON) in the analysis folder
  fields = ['Year', 'Very Safe State Voters', 'Overall Margin of Victory']
  utilities.writeCSV "./analysis/time_series.csv", timeSeries, fields

buildFig4 = ->

  # Result array we'll write to disk
  solution = []

  # We will scan through the 2012 data for 51 states (including DC)
  _.each _.keys(evMvData[2012]['states']), (state) ->

    # Store the state name and margin of victory per electoral vote
    ev = evMvData[2012]['states'][state]['ev']
    mv = evMvData[2012]['states'][state]['margin']
    solution.push
      'State': state
      'Electoral Votes': ev
      'Voting Power': parseInt(mv/ev)

  # Now we sort by voting power and take the first 26 states
  solution = _.sortBy(solution, (row) -> row['Voting Power'])
    .reverse()
    .slice(0,26)

  # Write to disk as CSV (Excel can't open JSON) in the analysis folder
  fields = ['State', 'Electoral Votes', 'Voting Power']
  utilities.writeCSV "./analysis/solution.csv", solution, fields

# Light that match, son.
readData()
