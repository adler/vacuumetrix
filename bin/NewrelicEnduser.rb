#!/usr/bin/env ruby
### grab metrics from newrelic and put them into graphite
### David Lutz
### 2012-06-08

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
## new versions of ruby don't need the following line
require 'rubygems' if RUBY_VERSION < "1.9"
require 'curb'
require 'json'

def collect_field(application_id, field_name)
  t=Time.now.utc
  timenow=t.to_i
  s=t-60

  timebegin=s.strftime("%FT%T")
  timeend=t.strftime("%FT%T")

  metricURL = "https://api.newrelic.com/api/v1/applications/"+application_id+"/data.json?summary=1&metrics[]=EndUser&field="+field_name+"&begin="+timebegin+"&end="+timeend
  #puts metricURL

  response = Curl::Easy.perform(metricURL) do |curl| curl.headers["x-api-key"] = $newrelicapikey
  end

  body=response.body_str
  result = JSON.parse(body)

  r3=result[0]

  appname = r3["app"].gsub( /[ \.()]/, "_")
  metricpath = "newrelic." + appname + "." + field_name
  metricvalue = r3[field_name]
  metrictimestamp = timenow.to_s

  Sendit metricpath, metricvalue, metrictimestamp
end

if ARGV.length < 1
  puts "usage: NewrelicEnduser.rb <application id> [-a | field name ...]"
  exit 1
end
application = ARGV.shift

ALL_RUM_FIELDS = ['average_response_time', 'average_be_response_time',
'average_fe_response_time', 'calls_per_minute', 'call_count',
'min_response_time', 'max_response_time', 'requests_per_minute']

if ARGV[0] == '-a'
  fields = ALL_RUM_FIELDS
else
  fields = ARGV
end

fields.each do |field|
  collect_field application, field
end
