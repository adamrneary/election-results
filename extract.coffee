cheerio = require("cheerio")
_ = require('underscore')
progressBar = require('progress')
utilities = require('./utilities')

# It's a bit hacky to hard-code the request count, but this is a simple extract.
requestCount = 40

# This object will hold our data until it gets written to file.
results = {}

# We'll use a simple progress bar for user feedback as data is extracted
# See https://github.com/visionmedia/node-progress/blob/master/examples/exact.js
bar = new progressBar('  progress [:bar]', requestCount)

# This method builds all requests that we need and sends them out,
# passing callback functions to handle the responses.
generateRequests = ->
  urlBase = "http://uselectionatlas.org/RESULTS/data.php"

  # Thankfully, the query format we need to use is semantic enough that we can
  # loop through our target years, generating simple requests
  for year in [1860..2012] by 4
    queryString = "?year=#{year}&datatype=national&def=1&f=0&off=0&elect=0"
    utilities.sendRequest(urlBase + queryString, extractData)

  # The population endpoint returns a CSV file we simply save as is
  popUrl = "http://www.census.gov/popest/data/state/totals/2012/tables/NST-EST2012-01.csv"
  utilities.sendRequest(popUrl, exportPopulationData)

# This method handles each response from the requests we generate above.
extractData = (err, resp, html) ->
  return console.error(err) if err

  # Cheerio is a great library for HTML parsing. Since the language for
  # navigating the results is so similar to jquery, we use "$" as the variable
  # to hold the resulting DOM, and the css selectors that follow will feel very
  # familiar for folks with front-end engineering experience.
  $ = cheerio.load(html)

  # The year is the first word in the .header div
  year = $('.header').text().split(' ')[0]
  results[year] =
    states: {}

  # State-specific data is in the table described here
  dataTableRows = $('table#data td#data table.data').find('tr')

  # Retrieve and remove the header and summary rows
  headerRow = dataTableRows[0]
  summaryRow = dataTableRows[dataTableRows.length - 1]
  dataTableRows = dataTableRows.slice(1, dataTableRows.length - 1)

  # Now we need to parse the column headers, as the table columns vary by year.
  # There will be multiple columns for electoral vote count (one for each party)
  # but only one column for the others
  #
  # We'll just store the columns indexes so we can use them for each row.
  evColumns = []
  totalVoteColumn = ''
  marginColumn = ''
  marginPercentColumn = ''

  $(headerRow).find('td').each (i, columnHeader) ->
    switch $(columnHeader).text()
      when 'EV' then evColumns.push i
      when 'Total Vote' then totalVoteColumn = i
      when 'Margin' then marginColumn = i
      when '%Margin' then marginPercentColumn = i

  # First let's record the overall popular vote and margin of victory
  columns = $(summaryRow).find('td')
  tmpString = $(columns[totalVoteColumn]).text()
  results[year]['overallPopularVote'] = parseInt(tmpString.replace(/,/g,''))
  tmpString = $(columns[marginPercentColumn]).text()
  results[year]['overallMargin'] = parseFloat(tmpString.replace(/%/g,''))

  # Now let's iterate through the states themselves
  $(dataTableRows).each (i, stateRow) ->
    columns = $(stateRow).find('td')

    # Capture the state name and create a record for it
    state = $(columns[0]).text()
    results[year]['states'][state] or= {}

    # Capture and total the EVs
    results[year]['states'][state]['ev'] = 0
    _.each evColumns, (evColumn) ->
      tmpString = $(columns[evColumn]).text()
      results[year]['states'][state]['ev'] += parseInt(tmpString.replace(/,/g,''))

    # Capture the total vote
    tmpString = $(columns[totalVoteColumn]).text()
    results[year]['states'][state]['popular_vote'] = parseInt(tmpString.replace(/,/g,''))

    # Capture the margin
    tmpString = $(columns[marginColumn]).text()
    results[year]['states'][state]['margin'] = parseInt(tmpString.replace(/,/g,''))

    # Capture the margin %
    tmpString = $(columns[marginPercentColumn]).text()
    results[year]['states'][state]['margin_percent'] = parseInt(tmpString.replace(/,/g,''))


  # Update progress and see if we're done (see method explanation below)
  checkProgress()

# This method takes a look at the results object to determine how many requests
# have completed. It reports progress and handles the completion event.
#
# This bit can be somewhat counter-intuitive if you aren't accustomed to
# working with asynchronous requests. If we simply call exportResults at the
# conclusion of generateRequests, most of the requets will not have come back
# yet.
#
# Rather, extractData will be called 39 times with indeterminate amounts of
# time, so we simply create a mechanism for determining whether the entire
# process is complete. We can use this approach to provide the user feedback
# while all the requests are running, and once complete, we can trigger the
# results export. Boom.
checkProgress = ->

  # By counting the keys in each object we know which requests have been parsed
  completedCount = _.keys(results).length

  # The bar is hard-coded for 40 requests, so we can just tick it each time
  bar.tick()

  # Trigger export if we're done. We add 1 for the separate population data
  # request, presuming the population data will be in by this point
  if completedCount + 1 is requestCount
    utilities.writeFile "./data/ev_mv.json", JSON.stringify(results, null, 2)

# This is just a simple helper function in case the CSV retrieval itself fails
# and returns an error
exportPopulationData = (err, resp, csvData) ->
  return console.error(err) if err
  bar.tick()
  utilities.writeFile "./data/population.csv", csvData

# Light that match, son.
generateRequests()
