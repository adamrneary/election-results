fs = require('fs')
request = require('request')
json2csv = require('json2csv')

module.exports =

  # This helper isn't particularly useful, but it allows us to write 1-line
  # function calls within our other libraries. Just a bit cleaner.
  writeFile: (path, data) ->
    fs.writeFile path, data, (err) ->
      console.error(err) if err

  # This helper is a bit more useful, as it eliminates more lines in our
  # function calls within our libraries. Much cleaner.
  writeCSV: (path, data, fields) ->
    json2csv
        data: data
        fields: fields
      , (err, csvData) ->
        return console.error(err) if err
        fs.writeFile path, csvData, (err) ->
          console.error(err) if err

  # Once we've built a valid query string, we'll send an asyncronous
  # request, which means that the program won't wait for the response before
  # continuing. Instead, we pass the extractData method as a callback for
  # when the data arrives.
  sendRequest: (url, callback) ->
    options =
      url: url
      headers:
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.64 Safari/537.11'
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        'Accept-Charset': 'ISO-8859-1,utf-8;q=0.7,*;q=0.3'
        'Accept-Encoding': 'none'
        'Accept-Language': 'en-US,en;q=0.8'
        'Connection': 'keep-alive'

    request(options, callback)
