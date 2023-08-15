require 'httparty'
require 'pry'
require 'mechanize'
require 'io/console'

FROM_DATE = Time.new(2023, 7, 1).to_i
TO_DATE = Time.new(2023, 7, 31).to_i
FUEL_PER_LITRE = 1.906
LITRES_PER_100KM = 7.4
page = 1
kms = 0

def login!
  agent = Mechanize.new

  # get the login form & fill it out with the username/password

  modal = agent.get("https://www.strava.com/login").forms.last
  modal.email = EMAIL
  modal.password = PASSWORD
  agent.submit(modal, modal.buttons.first)

  a = agent.get("https://www.strava.com/oauth/authorize?client_id=55475&redirect_uri=https://developers.strava.com&response_type=code&scope=activity:read").forms.last
  fs = a.submit

  login_res = CGI.parse(fs.uri.query)
  abort 'Login failed!' unless login_res
  login_res['code']
end

def bearer_token
  # get the login form & fill it out with the username/password

  uri = URI.parse("https://www.strava.com/oauth/token")
  response = Net::HTTP.start(uri.host, uri.port,
                              use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Post.new uri
    request['Content-Type'] = 'application/json'
    request.body = {
      "client_id": 55475,
      "code": login!.first,
      "client_secret": "f15e125ee64fa2f97b74ede0edeb386fdec8b571",
      "grant_type": "authorization_code"
    }.to_json
    http.request(request)
  end

  JSON.parse(response.body)['access_token']
end

puts 'Enter email!'
EMAIL = gets.chomp

puts 'Enter password!'
PASSWORD = $stdin.noecho(&:gets).chomp

puts 'Logging in on Strava'

loop do
  response = HTTParty.get(
    "https://www.strava.com/api/v3/athlete/activities?after=#{FROM_DATE}&before=#{TO_DATE}&page=#{page}&per_page=100",
    headers: { 'Authorization' => "Bearer #{bearer_token}" }
  )
  break if response.empty?

  kms += JSON.parse(response.body).
           reject { |x| x['type'] == 'VirtualRide' }.
           sum { |v| v['distance'] }

  page += 1
rescue => e
  break
end

puts "Kms: #{kms / 1000.0}"
puts "Saved #{FUEL_PER_LITRE * LITRES_PER_100KM * (kms / 100000.0)} euros!"
