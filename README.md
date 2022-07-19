# Fedapay::Ruby

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/fedapay/ruby`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Require

Please specify version 1.8 of faraday in your project if you have already installed it beforehand

``` ruby
gem 'faraday', '~>1.8'
```

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'fedapay', '~>0.1.20', git: 'https://github.com/fedapay/fedapay-ruby.git'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fedapay-ruby

## Usage

``` ruby
require fedapay

# configure FedaPay library
FedaPay.api_key = '' # Your secret api key
FedaPay.environment = '' # sandbox or live
```

## Customer operations

``` ruby
# customers list
customers = FedaPay::Customer.list

# get a customer by id
customer = FedaPay::Customer.retrieve 1

# create a customer
phone = {
  country: 'bj',
  number: '66000001'
}

customer = FedaPay::Customer.create firstname: 'firstname', lastname: 'lastname',
                                    email: 'email@test.com', phone_number: phone

# update a customer instance
customer.firstname = 'My Firstname'
customer.save

# or
customer.save fistname: 'My Firstname', lastname: 'My Lastname'

# Update a customer by id
customer = FedaPay::Customer.update 202, email: 'myemail@test.com'

# Delete a customer by instance
customer.delete
```

## Transaction operations
``` ruby
# transactions list
transactions = FedaPay::Transaction.list

# Get a transaction
transaction = FedaPay::Transaction.retrieve 2

# Create a transaction with existing customer instance
currencies = FedaPay::Currency.list
customer = FedaPay::Customer.retrieve 2

transaction = FedaPay::Transaction.create amount: 1000, currency: currencies.first.to_hash, customer = customer.to_hash, description: ''

# Create a transaction with existing customer by id or email
customer = {
  id: 1, # Or email
  email: 'customer@test.com'
}

currency = {
  iso: 'XOF', # Or code,
  code: '952'
}

transaction = FedaPay::Transaction.create amount: 1000, currency: currencies, customer = customer, description: ''

# New customer can also be created when creating a transaction
customer = {
  email: 'customer@test.com',
  firstname: 'New firstname',
  lastname: 'New Lastname'
}
...

# Update a transaction instance
transaction.amount = 5000
transaction.save

# Or

transaction.save amount: 5000

# Update a transaction by id
FedaPay.update 2, amount: 5000

# Delete a transaction
transaction.delete

# Generate a secured payment link for a transaction or get it token
data = transaction.generate_token

# data structure is :
# {
#   token: '',
#   url: 'https://...'
# }
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/fedapay-ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Fedapay::Ruby project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/fedapay-ruby/blob/master/CODE_OF_CONDUCT.md).
